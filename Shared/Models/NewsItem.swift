//
//  NewsItem.swift
//  RSSFilter
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
            UserDefaults.standard.bool(forKey: "read_\(id)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "read_\(id)")
        }
    }
    
    var isFavorite: Bool {
        get {
            UserDefaults.standard.bool(forKey: "favorite_\(id)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "favorite_\(id)")
        }
    }
}
