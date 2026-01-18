//
//  AppleIntelligenceService.swift
//  RSSFilter
//

import Foundation
#if canImport(Translation)
import Translation
#endif

@available(iOS 18.0, macOS 15.0, *)
class AppleIntelligenceService: AIService {
    
    func scoreQuality(newsItem: NewsItem) async throws -> QualityScore {
        // Use Apple Intelligence APIs for quality scoring
        // Note: This is a simplified implementation
        // In production, you'd use Writing Tools API or similar
        
        let prompt = """
        Analyze this news article and score its quality from 0-100.
        
        Title: \(newsItem.title)
        Summary: \(newsItem.summary)
        
        Evaluate:
        - Is it clickbait?
        - Is it spam?
        - Is it advertisement?
        - Overall content quality (high/medium/low)
        
        Respond in JSON format:
        {
            "score": 85,
            "isClickbait": false,
            "isSpam": false,
            "isAdvertisement": false,
            "contentQuality": "high",
            "reasoning": "Well-written article with factual information"
        }
        """
        
        // Simulate Apple Intelligence analysis
        // In real implementation, use Writing Tools or Foundation LLM APIs
        let score = analyzeContent(newsItem)
        
        return QualityScore(
            overallScore: score.score,
            isClickbait: score.isClickbait,
            isSpam: score.isSpam,
            isAdvertisement: score.isAd,
            contentQuality: score.quality,
            reasoning: score.reasoning
        )
    }
    
    func detectDuplicates(newsItems: [NewsItem]) async throws -> [DuplicateGroup] {
        var groups: [UUID: [NewsItem]] = [:]
        
        // Simple duplicate detection using title similarity
        for item in newsItems {
            let normalizedTitle = item.title.lowercased()
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            
            var found = false
            for (groupID, existingItems) in groups {
                if let first = existingItems.first {
                    let firstNormalized = first.title.lowercased()
                        .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
                    
                    let similarity = calculateSimilarity(normalizedTitle, firstNormalized)
                    if similarity > 0.7 {
                        groups[groupID]?.append(item)
                        found = true
                        break
                    }
                }
            }
            
            if !found {
                groups[UUID()] = [item]
            }
        }
        
        // Return only groups with 2+ items (actual duplicates)
        return groups.compactMap { (id, items) in
            items.count > 1 ? DuplicateGroup(id: id, newsItems: items) : nil
        }
    }
    
    func classifyIntoSmartFolders(newsItem: NewsItem, smartFolders: [SmartFolder]) async throws -> [UUID] {
        var matchingFolders: [UUID] = []
        
        let content = "\(newsItem.title) \(newsItem.summary)".lowercased()
        
        for folder in smartFolders where folder.isEnabled {
            let keywords = folder.description.lowercased().split(separator: " ")
            let matches = keywords.filter { content.contains($0) }
            
            // If 50% or more keywords match, classify into this folder
            if Double(matches.count) / Double(keywords.count) >= 0.5 {
                matchingFolders.append(folder.id)
            }
        }
        
        return matchingFolders
    }
    
    // MARK: - Helper Methods
    
    private func analyzeContent(_ newsItem: NewsItem) -> (score: Int, isClickbait: Bool, isSpam: Bool, isAd: Bool, quality: QualityScore.ContentQuality, reasoning: String) {
        let title = newsItem.title.lowercased()
        let summary = newsItem.summary.lowercased()
        
        var score = 70 // Base score
        var isClickbait = false
        var isSpam = false
        var isAd = false
        
        // Clickbait detection
        let clickbaitWords = ["shocking", "unbelievable", "you won't believe", "secret", "trick", "hate", "love"]
        if clickbaitWords.contains(where: { title.contains($0) }) {
            isClickbait = true
            score -= 30
        }
        
        // Spam detection
        let spamWords = ["free", "click here", "buy now", "limited time", "act now"]
        if spamWords.contains(where: { title.contains($0) || summary.contains($0) }) {
            isSpam = true
            score -= 40
        }
        
        // Ad detection
        let adWords = ["sponsored", "advertisement", "promoted", "ad", "affiliate"]
        if adWords.contains(where: { title.contains($0) || summary.contains($0) }) {
            isAd = true
            score -= 20
        }
        
        // Length-based quality
        if summary.count > 200 {
            score += 10
        }
        if summary.count < 50 {
            score -= 10
        }
        
        score = max(0, min(100, score))
        
        let quality: QualityScore.ContentQuality
        if score >= 70 {
            quality = .high
        } else if score >= 40 {
            quality = .medium
        } else {
            quality = .low
        }
        
        let reasoning = """
        Score: \(score)
        Clickbait: \(isClickbait)
        Spam: \(isSpam)
        Advertisement: \(isAd)
        """
        
        return (score, isClickbait, isSpam, isAd, quality, reasoning)
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let words1 = Set(str1.split(separator: " "))
        let words2 = Set(str2.split(separator: " "))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return Double(intersection.count) / Double(union.count)
    }
}
