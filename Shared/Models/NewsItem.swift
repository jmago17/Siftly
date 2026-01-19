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
    
    // AI-powered fields
    var qualityScore: QualityScore?
    var duplicateGroupID: UUID?
    var smartFolderIDs: [UUID] = []
    
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
}
