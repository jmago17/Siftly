//
//  FeedsViewModel.swift
//  RSSFilter
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FeedsViewModel: ObservableObject {
    @Published var feeds: [RSSFeed] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var iCloudSyncEnabled = true

    private let userDefaultsKey = "rssFeeds"
    private let timeout: TimeInterval = 10.0
    private let cloudSync = CloudSyncService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadFromDisk()
        setupCloudSync()
    }

    private func setupCloudSync() {
        NotificationCenter.default.publisher(for: .cloudDataDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncFromCloud()
                }
            }
            .store(in: &cancellables)
    }

    func syncFromCloud() {
        guard iCloudSyncEnabled else { return }

        if let cloudFeeds = cloudSync.loadFeeds() {
            // Merge cloud feeds with local feeds
            mergeFeeds(cloudFeeds)
        }
    }

    private func mergeFeeds(_ cloudFeeds: [RSSFeed]) {
        var mergedFeeds = feeds

        for cloudFeed in cloudFeeds {
            if let index = mergedFeeds.firstIndex(where: { $0.id == cloudFeed.id }) {
                // Update existing feed if cloud version is newer
                if let cloudUpdate = cloudFeed.lastUpdated,
                   let localUpdate = mergedFeeds[index].lastUpdated,
                   cloudUpdate > localUpdate {
                    mergedFeeds[index] = cloudFeed
                }
            } else {
                // Add new feed from cloud
                mergedFeeds.append(cloudFeed)
            }
        }

        feeds = mergedFeeds
        saveToDisk()
    }
    
    // MARK: - CRUD Operations
    
    func addFeed(_ feed: RSSFeed) {
        feeds.append(feed)
        saveToDisk()
    }
    
    func updateFeed(_ feed: RSSFeed) {
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index] = feed
            saveToDisk()
        }
    }
    
    func deleteFeed(id: UUID) {
        feeds.removeAll { $0.id == id }
        saveToDisk()
    }
    
    func toggleFeed(id: UUID) {
        if let index = feeds.firstIndex(where: { $0.id == id }) {
            feeds[index].isEnabled.toggle()
            saveToDisk()
        }
    }
    
    // MARK: - Fetching
    
    func fetchAllFeeds() async -> [NewsItem] {
        var allItems: [NewsItem] = []
        
        let enabledFeeds = feeds.filter { $0.isEnabled }
        
        await withTaskGroup(of: (UUID, Result<[NewsItem], Error>).self) { group in
            for feed in enabledFeeds {
                group.addTask {
                    do {
                        let items = try await self.fetchFeed(feed)
                        return (feed.id, .success(items))
                    } catch {
                        return (feed.id, .failure(error))
                    }
                }
            }
            
            for await (feedID, result) in group {
                if let index = self.feeds.firstIndex(where: { $0.id == feedID }) {
                    switch result {
                    case .success(let items):
                        allItems.append(contentsOf: items)
                        self.feeds[index].lastUpdated = Date()
                        self.feeds[index].lastFetchError = nil
                    case .failure(let error):
                        self.feeds[index].lastFetchError = error.localizedDescription
                    }
                }
            }
        }
        
        saveToDisk()
        return allItems
    }
    
    private func fetchFeed(_ feed: RSSFeed) async throws -> [NewsItem] {
        guard let url = URL(string: feed.url) else {
            throw FeedError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Mozilla/5.0 (compatible; RSSFilter/1.0)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw FeedError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let items = RSSParser.parse(data: data, feedID: feed.id, feedName: feed.name)
        
        guard !items.isEmpty else {
            throw FeedError.noItemsFound
        }
        
        return items
    }
    
    func validateFeedURL(_ urlString: String) async -> (Bool, String) {
        guard let url = URL(string: urlString) else {
            return (false, "URL inválida")
        }
        
        guard url.scheme == "http" || url.scheme == "https" else {
            return (false, "La URL debe comenzar con http:// o https://")
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = timeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Respuesta inválida")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                return (false, "Error HTTP: \(httpResponse.statusCode)")
            }
            
            let items = RSSParser.parse(data: data, feedID: UUID(), feedName: "test")
            
            if items.isEmpty {
                return (false, "No se encontraron elementos en el feed")
            }
            
            return (true, "Feed válido con \(items.count) elementos")
            
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(feeds)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)

            // Sync to iCloud if enabled
            if iCloudSyncEnabled {
                cloudSync.saveFeeds(feeds)
            }
        } catch {
            print("Error saving feeds: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            feeds = try decoder.decode([RSSFeed].self, from: data)
        } catch {
            print("Error loading feeds: \(error)")
            feeds = []
        }
    }
}

enum FeedError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case noItemsFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .httpError(let statusCode):
            return "Error HTTP: \(statusCode)"
        case .noItemsFound:
            return "No se encontraron noticias en el feed"
        }
    }
}
