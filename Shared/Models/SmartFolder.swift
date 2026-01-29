//
//  SmartFolder.swift
//  RSS RAIder
//

import Foundation

struct SmartFolder: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var isEnabled: Bool
    var matchCount: Int
    var filters: ArticleFilterOptions
    
    init(name: String, description: String) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.isEnabled = true
        self.matchCount = 0
        self.filters = ArticleFilterOptions()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isEnabled
        case matchCount
        case filters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        matchCount = try container.decodeIfPresent(Int.self, forKey: .matchCount) ?? 0
        filters = try container.decodeIfPresent(ArticleFilterOptions.self, forKey: .filters) ?? ArticleFilterOptions()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(matchCount, forKey: .matchCount)
        try container.encode(filters, forKey: .filters)
    }
}

extension SmartFolder {
    func matchesFilters(for item: NewsItem) -> Bool {
        let content = "\(item.title) \(item.aiSummary)"
        return filters.matches(
            content: content,
            url: item.link,
            feedTitle: item.feedName,
            author: item.author,
            date: item.pubDate
        )
    }
}
