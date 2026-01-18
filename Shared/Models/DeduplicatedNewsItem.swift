//
//  DeduplicatedNewsItem.swift
//  RSSFilter
//

import Foundation

/// Represents a news item that may have multiple sources (duplicates)
struct DeduplicatedNewsItem: Identifiable {
    let id: String
    let title: String
    let summary: String
    let pubDate: Date?

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
        self.sources = duplicates.map { NewsItemSource(from: $0) }

        // Use the best quality score among duplicates
        self.qualityScore = duplicates.compactMap { $0.qualityScore }
            .max(by: { $0.overallScore < $1.overallScore })

        // Combine all smart folder IDs
        self.smartFolderIDs = Array(Set(duplicates.flatMap { $0.smartFolderIDs }))
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

    /// Read status for this specific source
    var isRead: Bool {
        UserDefaults.standard.bool(forKey: "read_\(id)")
    }

    /// Favorite status for this specific source
    var isFavorite: Bool {
        UserDefaults.standard.bool(forKey: "favorite_\(id)")
    }

    init(from newsItem: NewsItem) {
        self.id = newsItem.id
        self.feedID = newsItem.feedID
        self.feedName = newsItem.feedName
        self.link = newsItem.link
        self.qualityScore = newsItem.qualityScore
    }

    /// Mark this source as read
    func markAsRead(_ isRead: Bool) {
        UserDefaults.standard.set(isRead, forKey: "read_\(id)")
    }
}
