//
//  OpenAIService.swift
//  RSSFilter
//

import Foundation

class OpenAIService: AIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
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
        
        Respond ONLY with valid JSON:
        {
            "score": 85,
            "isClickbait": false,
            "isSpam": false,
            "isAdvertisement": false,
            "contentQuality": "high",
            "reasoning": "Well-written article"
        }
        """
        
        let response = try await callOpenAI(prompt: prompt, maxTokens: 500)
        let data = response.data(using: .utf8)!
        
        struct OpenAIQualityResponse: Codable {
            let score: Int
            let isClickbait: Bool
            let isSpam: Bool
            let isAdvertisement: Bool
            let contentQuality: String
            let reasoning: String
        }
        
        let decoded = try JSONDecoder().decode(OpenAIQualityResponse.self, from: data)
        
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
        let newsJSON = try JSONEncoder().encode(newsItems.map { ["id": $0.id, "title": $0.title] })
        let newsString = String(data: newsJSON, encoding: .utf8)!
        
        let prompt = """
        Group duplicate or similar news articles.
        
        News: \(newsString)
        
        Return JSON:
        {
            "groups": [
                {"ids": ["id1", "id2"]},
                {"ids": ["id3", "id4", "id5"]}
            ]
        }
        
        Only groups with 2+ items.
        """
        
        let response = try await callOpenAI(prompt: prompt, maxTokens: 1000)
        let data = response.data(using: .utf8)!
        
        struct OpenAIDuplicateResponse: Codable {
            let groups: [[String: [String]]]
        }
        
        let decoded = try JSONDecoder().decode(OpenAIDuplicateResponse.self, from: data)
        
        return decoded.groups.compactMap { group in
            guard let ids = group["ids"], ids.count > 1 else { return nil }
            let items = newsItems.filter { ids.contains($0.id) }
            return items.count > 1 ? DuplicateGroup(id: UUID(), newsItems: items) : nil
        }
    }
    
    func classifyIntoSmartFolders(newsItem: NewsItem, smartFolders: [SmartFolder]) async throws -> [UUID] {
        let foldersJSON = try JSONEncoder().encode(smartFolders.map { ["id": $0.id.uuidString, "description": $0.description] })
        let foldersString = String(data: foldersJSON, encoding: .utf8)!
        
        let prompt = """
        Classify this article into matching folders.
        
        Article: \(newsItem.title) - \(newsItem.summary)
        
        Folders: \(foldersString)
        
        Return JSON: {"folderIDs": ["uuid1", "uuid2"]}
        """
        
        let response = try await callOpenAI(prompt: prompt, maxTokens: 300)
        let data = response.data(using: .utf8)!
        
        struct OpenAIFolderResponse: Codable {
            let folderIDs: [String]
        }
        
        let decoded = try JSONDecoder().decode(OpenAIFolderResponse.self, from: data)
        return decoded.folderIDs.compactMap { UUID(uuidString: $0) }
    }
    
    // MARK: - Private Methods
    
    private func callOpenAI(prompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.3
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
        
        struct OpenAIResponse: Codable {
            let choices: [Choice]
            struct Choice: Codable {
                let message: Message
                struct Message: Codable {
                    let content: String
                }
            }
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        var text = openAIResponse.choices.first?.message.content ?? ""
        
        // Clean markdown
        text = text.replacingOccurrences(of: "```json\\n?", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "```\\n?", with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text
    }
}
