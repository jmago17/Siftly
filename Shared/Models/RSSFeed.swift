//
//  RSSFeed.swift
//  RSS RAIder
//

import Foundation

struct RSSFeed: Codable, Identifiable {
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool
    var lastUpdated: Date?
    var lastFetchError: String?
    var priorityBoost: Int
    var isMutedInNews: Bool
    var openInSafariReader: Bool
    var showImagesInList: Bool

    init(name: String, url: String) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isEnabled = true
        self.lastUpdated = nil
        self.lastFetchError = nil
        self.priorityBoost = 0
        self.isMutedInNews = false
        self.openInSafariReader = false
        self.showImagesInList = true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case isEnabled
        case lastUpdated
        case lastFetchError
        case priorityBoost
        case isMutedInNews
        case openInSafariReader
        case showImagesInList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        lastFetchError = try container.decodeIfPresent(String.self, forKey: .lastFetchError)
        priorityBoost = try container.decodeIfPresent(Int.self, forKey: .priorityBoost) ?? 0
        isMutedInNews = try container.decodeIfPresent(Bool.self, forKey: .isMutedInNews) ?? false
        openInSafariReader = try container.decodeIfPresent(Bool.self, forKey: .openInSafariReader) ?? false
        showImagesInList = try container.decodeIfPresent(Bool.self, forKey: .showImagesInList) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(lastUpdated, forKey: .lastUpdated)
        try container.encodeIfPresent(lastFetchError, forKey: .lastFetchError)
        try container.encode(priorityBoost, forKey: .priorityBoost)
        try container.encode(isMutedInNews, forKey: .isMutedInNews)
        try container.encode(openInSafariReader, forKey: .openInSafariReader)
        try container.encode(showImagesInList, forKey: .showImagesInList)
    }
}
