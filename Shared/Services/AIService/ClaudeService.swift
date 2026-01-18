//
//  ClaudeService.swift
//  RSSFilter
//

import Foundation

class ClaudeService: AIService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func scoreQuality(newsItem: NewsItem) async throws -> QualityScore {
        let prompt = """
        Analyze this news article and score its quality from 0-100.
        
        Title: \(newsItem.title)
        Summary: \(newsItem.summary)
        
        Evaluate:
        - Is it clickbait? (yes/no)
        - Is it spam? (yes/no)
        - Is it advertisement? (yes/no)
        - Overall content quality (high/medium/low)
        - Brief reasoning for the score
        
        Respond ONLY with valid JSON in this exact format:
        {
            "score": 85,
            "isClickbait": false,
            "isSpam": false,
            "isAdvertisement": false,
            "contentQuality": "high",
            "reasoning": "Well-written article with factual information"
        }
        """
        
        let response = try await callClaude(prompt: prompt, maxTokens: 500)
        let data = response.data(using: .utf8)!
        
        struct ClaudeQualityResponse: Codable {
            let score: Int
            let isClickbait: Bool
            let isSpam: Bool
            let isAdvertisement: Bool
            let contentQuality: String
            let reasoning: String
        }
        
        let decoded = try JSONDecoder().decode(ClaudeQualityResponse.self, from: data)
        
        let quality: QualityScore.ContentQuality
        switch decoded.contentQuality.lowercased() {
        case "high": quality = .high
        case "medium": quality = .medium
        default: quality = .low
        }
        
        return QualityScore(
            overallScore: decoded.score,
            isClickbait: decoded.isClickbait,
            isSpam: decoded.isSpam,
            isAdvertisement: decoded.isAdvertisement,
            contentQuality: quality,
            reasoning: decoded.reasoning
        )
    }
    
    func detectDuplicates(newsItems: [NewsItem]) async throws -> [DuplicateGroup] {
        let newsJSON = try JSONEncoder().encode(newsItems.map { ["id": $0.id, "title": $0.title, "summary": $0.summary] })
        let newsString = String(data: newsJSON, encoding: .utf8)!
        
        let prompt = """
        Analyze these news articles and group duplicates or very similar stories together.
        
        News items:
        \(newsString)
        
        Return JSON array of duplicate groups. Each group should have an array of IDs:
        {
            "groups": [
                {"ids": ["id1", "id2", "id3"]},
                {"ids": ["id4", "id5"]}
            ]
        }
        
        Only include groups with 2+ items. If no duplicates found, return empty array.
        """
        
        let response = try await callClaude(prompt: prompt, maxTokens: 1000)
        let data = response.data(using: .utf8)!
        
        struct ClaudeDuplicateResponse: Codable {
            let groups: [[String: [String]]]
        }
        
        let decoded = try JSONDecoder().decode(ClaudeDuplicateResponse.self, from: data)
        
        return decoded.groups.compactMap { group in
            guard let ids = group["ids"], ids.count > 1 else { return nil }
            let items = newsItems.filter { ids.contains($0.id) }
            return items.count > 1 ? DuplicateGroup(id: UUID(), newsItems: items) : nil
        }
    }
    
    func classifyIntoSmartFolders(newsItem: NewsItem, smartFolders: [SmartFolder]) async throws -> [UUID] {
        let foldersJSON = try JSONEncoder().encode(smartFolders.map { ["id": $0.id.uuidString, "name": $0.name, "description": $0.description] })
        let foldersString = String(data: foldersJSON, encoding: .utf8)!
        
        let prompt = """
        Classify this news article into the appropriate smart folders.
        
        Article:
        Title: \(newsItem.title)
        Summary: \(newsItem.summary)
        
        Smart Folders:
        \(foldersString)
        
        Return JSON with array of matching folder IDs:
        {
            "folderIDs": ["uuid1", "uuid2"]
        }
        
        An article can match multiple folders. Return empty array if no matches.
        """
        
        let response = try await callClaude(prompt: prompt, maxTokens: 300)
        let data = response.data(using: .utf8)!
        
        struct ClaudeFolderResponse: Codable {
            let folderIDs: [String]
        }
        
        let decoded = try JSONDecoder().decode(ClaudeFolderResponse.self, from: data)
        return decoded.folderIDs.compactMap { UUID(uuidString: $0) }
    }
    
    // MARK: - Private Methods
    
    private func callClaude(prompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw AIServiceError.rateLimited
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }
        
        struct ClaudeResponse: Codable {
            let content: [ContentBlock]
            struct ContentBlock: Codable {
                let text: String
            }
        }
        
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        var text = claudeResponse.content.first?.text ?? ""
        
        // Clean markdown code blocks
        text = text.replacingOccurrences(of: "```json\\n?", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "```\\n?", with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text
    }
}
