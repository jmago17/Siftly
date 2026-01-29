//
//  SmartFeed.swift
//  RSS RAIder
//

import Foundation

enum SmartFeedKind: String, Codable {
    case regular
    case favorites
}

struct SmartFeed: Codable, Identifiable {
    let id: UUID
    var name: String
    var feedIDs: [UUID]
    var isEnabled: Bool
    var showImagesInList: Bool
    var filters: ArticleFilterOptions
    var iconSystemName: String
    var kind: SmartFeedKind

    static let favoritesID = UUID(uuidString: "7E2C5E8C-6C66-4A6C-8F32-4F10A5CCB8F2")!

    init(
        id: UUID = UUID(),
        name: String,
        feedIDs: [UUID],
        kind: SmartFeedKind = .regular,
        iconSystemName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.feedIDs = feedIDs
        self.isEnabled = true
        self.showImagesInList = true
        self.filters = ArticleFilterOptions()
        self.kind = kind
        self.iconSystemName = iconSystemName ?? (kind == .favorites ? "star.fill" : "sparkles")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case feedIDs
        case isEnabled
        case showImagesInList
        case filters
        case iconSystemName
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        feedIDs = try container.decode([UUID].self, forKey: .feedIDs)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        showImagesInList = try container.decodeIfPresent(Bool.self, forKey: .showImagesInList) ?? true
        filters = try container.decodeIfPresent(ArticleFilterOptions.self, forKey: .filters) ?? ArticleFilterOptions()
        kind = try container.decodeIfPresent(SmartFeedKind.self, forKey: .kind) ?? .regular
        iconSystemName = try container.decodeIfPresent(String.self, forKey: .iconSystemName)
            ?? (kind == .favorites ? "star.fill" : "sparkles")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(feedIDs, forKey: .feedIDs)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(showImagesInList, forKey: .showImagesInList)
        try container.encode(filters, forKey: .filters)
        try container.encode(iconSystemName, forKey: .iconSystemName)
        try container.encode(kind, forKey: .kind)
    }
}
