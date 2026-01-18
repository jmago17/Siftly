//
//  DuplicateGroup.swift
//  RSSFilter
//

import Foundation

struct DuplicateGroup: Identifiable {
    let id: UUID
    var newsItems: [NewsItem]
    var primaryItem: NewsItem {
        // Return the one with highest quality score
        newsItems.max(by: { 
            ($0.qualityScore?.overallScore ?? 0) < ($1.qualityScore?.overallScore ?? 0)
        }) ?? newsItems.first!
    }
    var duplicateCount: Int {
        newsItems.count - 1
    }
}
