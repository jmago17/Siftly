//
//  NewsItem.swift
//  RSS RAIder
//

import Foundation

struct NewsItem: Codable, Identifiable {
    let id: String
    var title: String
    var summary: String
    var link: String
    var pubDate: Date?
    var feedID: UUID
    var feedName: String
    var imageURL: String?
    var author: String?

    // Raw HTML from RSS fields (optional, for improved extraction)
    var rawSummary: String?
    var rawContent: String?

    // Cleaned article text for AI and reading views
    var cleanTitle: String?
    var cleanBody: String?
    
    // AI-powered fields
    var qualityScore: QualityScore?
    var duplicateGroupID: UUID?
    var smartFolderIDs: [UUID] = [] // Legacy - kept for backwards compatibility
    var tagIDs: [UUID] = [] // Smart tags assigned by AI
    
    // User interactions
    var isRead: Bool {
        get {
            // Try iCloud first, then fall back to local UserDefaults
            if let cloudState = CloudSyncService.shared.getReadState(id) {
                return cloudState
            }
            return UserDefaults.standard.bool(forKey: "read_\(id)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "read_\(id)")
            CloudSyncService.shared.saveReadState(id, isRead: newValue)
        }
    }

    var isFavorite: Bool {
        get {
            // Try iCloud first, then fall back to local UserDefaults
            if let cloudState = CloudSyncService.shared.getFavoriteState(id) {
                return cloudState
            }
            return UserDefaults.standard.bool(forKey: "favorite_\(id)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "favorite_\(id)")
            CloudSyncService.shared.saveFavoriteState(id, isFavorite: newValue)
        }
    }

    var aiTitle: String {
        if let cleanTitle = cleanTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanTitle.isEmpty {
            return cleanTitle
        }
        return title
    }

    var aiSummary: String {
        let base: String
        if let cleanBody = cleanBody?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanBody.isEmpty {
            base = cleanBody
        } else {
            base = summary
        }

        if base.count > 3000 {
            return String(base.prefix(3000))
        }

        return base
    }
}
