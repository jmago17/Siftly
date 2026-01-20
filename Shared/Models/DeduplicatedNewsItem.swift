//
//  DeduplicatedNewsItem.swift
//  RSS RAIder
//

import Foundation

/// Represents a news item that may have multiple sources (duplicates)
struct DeduplicatedNewsItem: Identifiable {
    let id: String
    let title: String
    let summary: String
    let pubDate: Date?
    let imageURL: String?
    let author: String?

    /// All news items that are duplicates (including the primary one)
    let sources: [NewsItemSource]

    /// Quality score of the primary item
    let qualityScore: QualityScore?

    /// Smart folder IDs
    let smartFolderIDs: [UUID]

    /// Read status - true if ANY source has been read
    var isRead: Bool {
        sources.contains { $0.isRead }
    }

    /// Favorite status - true if ANY source is favorited
    var isFavorite: Bool {
        sources.contains { $0.isFavorite }
    }

    /// Primary source (best quality or first)
    var primarySource: NewsItemSource {
        // Prefer the source with highest quality score
        sources.max(by: { s1, s2 in
            let score1 = s1.qualityScore?.overallScore ?? 0
            let score2 = s2.qualityScore?.overallScore ?? 0
            return score1 < score2
        }) ?? sources[0]
    }

    /// Initialize from a single news item
    init(from newsItem: NewsItem) {
        self.id = newsItem.id
        self.title = newsItem.title
        self.summary = newsItem.summary
        self.pubDate = newsItem.pubDate
        self.imageURL = newsItem.imageURL
        self.author = newsItem.author
        self.sources = [NewsItemSource(from: newsItem)]
        self.qualityScore = newsItem.qualityScore
        self.smartFolderIDs = newsItem.smartFolderIDs
    }

    /// Initialize from multiple duplicate items
    init(duplicates: [NewsItem]) {
        guard let first = duplicates.first else {
            fatalError("Cannot create DeduplicatedNewsItem from empty array")
        }

        self.id = first.id
        self.title = first.title
        self.summary = first.summary
        self.pubDate = first.pubDate
        self.imageURL = duplicates.compactMap { $0.imageURL }.first
        self.author = duplicates.compactMap { $0.author }.first
        self.sources = duplicates.map { NewsItemSource(from: $0) }

        // Use the best quality score among duplicates
        self.qualityScore = duplicates.compactMap { $0.qualityScore }
            .max(by: { $0.overallScore < $1.overallScore })

        // Combine all smart folder IDs
        self.smartFolderIDs = Array(Set(duplicates.flatMap { $0.smartFolderIDs }))
    }

    /// Initialize with pre-filtered sources
    init(id: String, title: String, summary: String, pubDate: Date?, sources: [NewsItemSource], smartFolderIDs: [UUID], author: String? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.pubDate = pubDate
        self.sources = sources
        self.imageURL = sources.compactMap { $0.imageURL }.first
        self.author = author ?? sources.compactMap { $0.author }.first
        self.qualityScore = sources.compactMap { $0.qualityScore }
            .max(by: { $0.overallScore < $1.overallScore })
        self.smartFolderIDs = smartFolderIDs
    }

    /// Check if this item has multiple sources
    var hasDuplicates: Bool {
        sources.count > 1
    }
}

/// Represents a single source of a news item
struct NewsItemSource: Identifiable {
    let id: String
    let feedID: UUID
    let feedName: String
    let link: String
    let qualityScore: QualityScore?
    let imageURL: String?
    let author: String?

    /// Read status for this specific source
    var isRead: Bool {
        // Try iCloud first, then fall back to local UserDefaults
        if let cloudState = CloudSyncService.shared.getReadState(id) {
            return cloudState
        }
        return UserDefaults.standard.bool(forKey: "read_\(id)")
    }

    /// Favorite status for this specific source
    var isFavorite: Bool {
        // Try iCloud first, then fall back to local UserDefaults
        if let cloudState = CloudSyncService.shared.getFavoriteState(id) {
            return cloudState
        }
        return UserDefaults.standard.bool(forKey: "favorite_\(id)")
    }

    init(from newsItem: NewsItem) {
        self.id = newsItem.id
        self.feedID = newsItem.feedID
        self.feedName = newsItem.feedName
        self.link = newsItem.link
        self.qualityScore = newsItem.qualityScore
        self.imageURL = newsItem.imageURL
        self.author = newsItem.author
    }

    /// Mark this source as read
    func markAsRead(_ isRead: Bool) {
        UserDefaults.standard.set(isRead, forKey: "read_\(id)")
        CloudSyncService.shared.saveReadState(id, isRead: isRead)
    }
}
