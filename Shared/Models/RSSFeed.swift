//
//  RSSFeed.swift
//  RSSFilter
//

import Foundation

struct RSSFeed: Codable, Identifiable {
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool
    var lastUpdated: Date?
    var lastFetchError: String?

    init(name: String, url: String) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isEnabled = true
        self.lastUpdated = nil
        self.lastFetchError = nil
    }
}
