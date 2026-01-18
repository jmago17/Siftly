//
//  QualityScore.swift
//  RSSFilter
//

import Foundation

struct QualityScore: Codable {
    let overallScore: Int // 0-100
    let isClickbait: Bool
    let isSpam: Bool
    let isAdvertisement: Bool
    let contentQuality: ContentQuality
    let reasoning: String
    
    enum ContentQuality: String, Codable {
        case high = "high"
        case medium = "medium"
        case low = "low"
    }
    
    var color: String {
        switch overallScore {
        case 0..<40: return "red"
        case 40..<70: return "yellow"
        default: return "green"
        }
    }
}
