//
//  NewsViewModel.swift
//  RSS RAIder
//

import Foundation
import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
class NewsViewModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    @Published var isProcessing = false
    @Published var iCloudSyncEnabled = true

    private var aiService: AIService?
    private let cloudSync = CloudSyncService.shared
    private let articleExtractor = ArticleTextExtractor.shared
    private let cacheFileName = "newsCache.json"
    private let maxCachedItems = 2000
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCachedNews()
        updateAIService()
        observeNewsChanges()

        // Sync states from iCloud on first launch
        Task { @MainActor in
            syncStatesFromCloud()
        }
    }

    // MARK: - iCloud Sync

    private func syncStatesFromCloud() {
        guard iCloudSyncEnabled else { return }

        // Load read states from iCloud and merge with local
        let cloudReadStates = cloudSync.loadAllReadStates()
        for (itemID, isRead) in cloudReadStates {
            // Only update if not already set locally
            if !UserDefaults.standard.bool(forKey: "read_\(itemID)") {
                UserDefaults.standard.set(isRead, forKey: "read_\(itemID)")
            }
        }

        // Load favorite states from iCloud and merge with local
        let cloudFavoriteStates = cloudSync.loadAllFavoriteStates()
        for (itemID, isFavorite) in cloudFavoriteStates {
            // Only update if not already set locally
            if !UserDefaults.standard.bool(forKey: "favorite_\(itemID)") {
                UserDefaults.standard.set(isFavorite, forKey: "favorite_\(itemID)")
            }
        }
    }
    
    // MARK: - AI Processing
    
    func processNewsItems(_ items: [NewsItem], smartFolders: [SmartFolder], feeds: [RSSFeed]) async {
        isProcessing = true
        updateAIService()

        var processedItems: [NewsItem] = []
        
        // Process each news item
        for var item in items {
            if let extracted = await extractArticleText(for: item) {
                let cleanedTitle = extracted.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedTitle.isEmpty, cleanedTitle.lowercased() != "articulo" {
                    item.cleanTitle = cleanedTitle
                }
                if extracted.confidence >= 0.35, extracted.body.count >= 80 {
                    item.cleanBody = extracted.body
                }
            }

            if let service = aiService {
                // 1. Score quality
                do {
                    let score = try await service.scoreQuality(newsItem: item)
                    item.qualityScore = score
                } catch {
                    print("Error scoring quality for \(item.title): \(error)")
                }
                
                // 2. Classify into smart folders
                do {
                    let folderIDs = try await service.classifyIntoSmartFolders(newsItem: item, smartFolders: smartFolders)
                    item.smartFolderIDs = folderIDs
                } catch {
                    print("Error classifying \(item.title): \(error)")
                }
            }
            
            processedItems.append(item)
        }
        
        // 3. Detect duplicates
        if let service = aiService {
            do {
                let duplicateService: AIService
                if #available(iOS 18.0, macOS 15.0, *) {
                    duplicateService = AppleIntelligenceService()
                } else {
                    duplicateService = service
                }

                let duplicateGroups = try await duplicateService.detectDuplicates(newsItems: processedItems)

                for group in duplicateGroups {
                    for item in group.newsItems {
                        if let index = processedItems.firstIndex(where: { $0.id == item.id }) {
                            processedItems[index].duplicateGroupID = group.id
                        }
                    }
                }

                applyDuplicateBonus(to: &processedItems, duplicateGroups: duplicateGroups)
            } catch {
                print("Error detecting duplicates: \(error)")
            }
        }

        let feedPriorities = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0.priorityBoost) })
        applyFeedPriorityBoost(to: &processedItems, feedPriorities: feedPriorities)
        
        newsItems = processedItems
        isProcessing = false
    }

    private func extractArticleText(for item: NewsItem) async -> ExtractedArticleText? {
        guard let url = URL(string: item.link) else { return nil }
        let feedItem = FeedItem(
            title: item.title,
            descriptionHTML: item.rawSummary ?? item.summary,
            contentHTML: item.rawContent,
            link: url
        )
        return await articleExtractor.extract(from: feedItem)
    }

    private func applyDuplicateBonus(to items: inout [NewsItem], duplicateGroups: [DuplicateGroup]) {
        for group in duplicateGroups {
            let bonus = max(0, group.newsItems.count - 1) * 10
            guard bonus > 0 else { continue }

            for item in group.newsItems {
                if let index = items.firstIndex(where: { $0.id == item.id }),
                   let score = items[index].qualityScore {
                    let newScore = min(100, score.overallScore + bonus)
                    let updatedReasoning = score.reasoning + "\nBonus duplicados: +\(bonus)"
                    items[index].qualityScore = QualityScore(
                        overallScore: newScore,
                        isClickbait: score.isClickbait,
                        isSpam: score.isSpam,
                        isAdvertisement: score.isAdvertisement,
                        contentQuality: score.contentQuality,
                        reasoning: updatedReasoning
                    )
                }
            }
        }
    }

    private func applyFeedPriorityBoost(to items: inout [NewsItem], feedPriorities: [UUID: Int]) {
        for index in items.indices {
            let boost = feedPriorities[items[index].feedID] ?? 0
            guard boost != 0 else { continue }

            if let score = items[index].qualityScore {
                let newScore = max(0, min(100, score.overallScore + boost))
                let sign = boost >= 0 ? "+" : ""
                let updatedReasoning = score.reasoning + "\nPrioridad del feed: \(sign)\(boost)"
                items[index].qualityScore = QualityScore(
                    overallScore: newScore,
                    isClickbait: score.isClickbait,
                    isSpam: score.isSpam,
                    isAdvertisement: score.isAdvertisement,
                    contentQuality: score.contentQuality,
                    reasoning: updatedReasoning
                )
            }
        }
    }
    
    // MARK: - Filtering

    func getNewsItems(for feedID: UUID? = nil, smartFolderID: UUID? = nil, favoritesOnly: Bool = false) -> [NewsItem] {
        var filtered = newsItems

        if let feedID = feedID {
            filtered = filtered.filter { $0.feedID == feedID }
        }

        if let smartFolderID = smartFolderID {
            filtered = filtered.filter { $0.smartFolderIDs.contains(smartFolderID) }
        }

        if favoritesOnly {
            filtered = filtered.filter { item in
                UserDefaults.standard.bool(forKey: "favorite_\(item.id)")
            }
        }

        // Sort by quality score (high to low), then by date
        return filtered.sorted { item1, item2 in
            let score1 = item1.qualityScore?.overallScore ?? 50
            let score2 = item2.qualityScore?.overallScore ?? 50

            if score1 != score2 {
                return score1 > score2
            }

            return (item1.pubDate ?? Date.distantPast) > (item2.pubDate ?? Date.distantPast)
        }
    }

    /// Get deduplicated news items (show duplicates only once with multiple sources)
    func getDeduplicatedNewsItems(for feedID: UUID? = nil, smartFolderID: UUID? = nil, favoritesOnly: Bool = false) -> [DeduplicatedNewsItem] {
        let items = getNewsItems(for: feedID, smartFolderID: smartFolderID, favoritesOnly: favoritesOnly)

        // Group items by duplicate group ID
        var grouped: [UUID?: [NewsItem]] = [:]
        var nonDuplicates: [NewsItem] = []

        for item in items {
            if let groupID = item.duplicateGroupID {
                if grouped[groupID] == nil {
                    grouped[groupID] = []
                }
                grouped[groupID]?.append(item)
            } else {
                nonDuplicates.append(item)
            }
        }

        // Create deduplicated items
        var result: [DeduplicatedNewsItem] = []

        // Add grouped duplicates (one item per group)
        for (_, duplicates) in grouped {
            if duplicates.count > 1 {
                result.append(DeduplicatedNewsItem(duplicates: duplicates))
            } else if let single = duplicates.first {
                result.append(DeduplicatedNewsItem(from: single))
            }
        }

        // Add non-duplicate items
        for item in nonDuplicates {
            result.append(DeduplicatedNewsItem(from: item))
        }

        // Sort by quality score and date
        return result.sorted { item1, item2 in
            let score1 = item1.qualityScore?.overallScore ?? 50
            let score2 = item2.qualityScore?.overallScore ?? 50

            if score1 != score2 {
                return score1 > score2
            }

            return (item1.pubDate ?? Date.distantPast) > (item2.pubDate ?? Date.distantPast)
        }
    }
    
    func getDuplicateGroups() -> [DuplicateGroup] {
        var groups: [UUID: [NewsItem]] = [:]

        for item in newsItems {
            if let groupID = item.duplicateGroupID {
                if groups[groupID] == nil {
                    groups[groupID] = []
                }
                groups[groupID]?.append(item)
            }
        }

        return groups.compactMap { (id, items) in
            items.count > 1 ? DuplicateGroup(id: id, newsItems: items) : nil
        }
    }

    // MARK: - Read Status Management

    func markAsRead(_ itemID: String, isRead: Bool, notify: Bool = true) {
        // Save to local UserDefaults
        UserDefaults.standard.set(isRead, forKey: "read_\(itemID)")

        // Sync to iCloud if enabled
        if iCloudSyncEnabled {
            cloudSync.saveReadState(itemID, isRead: isRead)
        }

        if notify {
            objectWillChange.send()
        }
    }

    func markAllAsRead(withScoreBelow threshold: Int) {
        for item in newsItems {
            if let score = item.qualityScore?.overallScore,
               score < threshold {
                markAsRead(item.id, isRead: true, notify: false)
            }
        }
        objectWillChange.send()
    }

    // MARK: - Favorite Management

    func markAsFavorite(_ itemID: String, isFavorite: Bool, notify: Bool = true) {
        // Save to local UserDefaults
        UserDefaults.standard.set(isFavorite, forKey: "favorite_\(itemID)")

        // Sync to iCloud if enabled
        if iCloudSyncEnabled {
            cloudSync.saveFavoriteState(itemID, isFavorite: isFavorite)
        }

        if notify {
            objectWillChange.send()
        }
    }
    
    // MARK: - Settings

    private func updateAIService() {
        if #available(iOS 18.0, macOS 15.0, *) {
            aiService = AppleIntelligenceService()
        } else {
            aiService = nil
        }
    }

    // MARK: - Persistence

    private func observeNewsChanges() {
        $newsItems
            .dropFirst()
            .debounce(for: .seconds(0.6), scheduler: RunLoop.main)
            .sink { [weak self] items in
                self?.saveCachedNews(items)
                WidgetExportStore.saveArticles(items)
            }
            .store(in: &cancellables)
    }

    private func saveCachedNews(_ items: [NewsItem]) {
        let trimmedItems = Array(items.prefix(maxCachedItems))
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trimmedItems)
            let url = try cacheURL()
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Error saving cached news: \(error)")
        }
    }

    private func loadCachedNews() {
        do {
            let url = try cacheURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cached = try decoder.decode([NewsItem].self, from: data)
            if !cached.isEmpty {
                newsItems = cached
                WidgetExportStore.saveArticles(cached)
            }
        } catch {
            print("Error loading cached news: \(error)")
        }
    }

    private func cacheURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let bundleID = Bundle.main.bundleIdentifier ?? "RSSFilter"
        let dir = base.appendingPathComponent(bundleID, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(cacheFileName)
    }
}

// MARK: - Widget Export

enum WidgetExportStore {
    static let appGroupID = "group.com.rssraider.app"
    static let feedsKey = "widget_feeds"
    static let foldersKey = "widget_folders"
    static let smartFeedsKey = "widget_smartfeeds"
    static let articlesKey = "widget_articles"

    static func saveFeeds(_ feeds: [RSSFeed]) {
        let payload = feeds.map { WidgetFeedExport(id: $0.id, name: $0.name, url: $0.url) }
        save(payload, key: feedsKey)
    }

    static func saveFolders(_ folders: [FeedFolder]) {
        let payload = folders.map { WidgetFolderExport(id: $0.id, name: $0.name, feedIDs: $0.feedIDs) }
        save(payload, key: foldersKey)
    }

    static func saveSmartFeeds(_ smartFeeds: [SmartFeed]) {
        let payload = smartFeeds.map { WidgetSmartFeedExport(id: $0.id, name: $0.name, feedIDs: $0.feedIDs) }
        save(payload, key: smartFeedsKey)
    }

    static func saveArticles(_ items: [NewsItem]) {
        let trimmed = Array(items.prefix(120))
        let payload = trimmed.map {
            WidgetArticleExport(
                id: $0.id,
                title: $0.title,
                feedID: $0.feedID,
                feedName: $0.feedName,
                link: $0.link,
                pubDate: $0.pubDate,
                qualityScore: $0.qualityScore?.overallScore
            )
        }
        save(payload, key: articlesKey)
    }

    private static func save<T: Encodable>(_ payload: T, key: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(payload)
            defaults.set(data, forKey: key)
            reloadWidgets()
        } catch {
            print("Widget export error: \(error)")
        }
    }

    private static func reloadWidgets() {
        #if canImport(WidgetKit)
        if #available(iOS 14.0, macOS 11.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}

struct WidgetFeedExport: Codable {
    let id: UUID
    let name: String
    let url: String
}

struct WidgetFolderExport: Codable {
    let id: UUID
    let name: String
    let feedIDs: [UUID]
}

struct WidgetSmartFeedExport: Codable {
    let id: UUID
    let name: String
    let feedIDs: [UUID]
}

struct WidgetArticleExport: Codable {
    let id: String
    let title: String
    let feedID: UUID
    let feedName: String
    let link: String
    let pubDate: Date?
    let qualityScore: Int?
}
