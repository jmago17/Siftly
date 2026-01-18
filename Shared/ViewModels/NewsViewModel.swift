//
//  NewsViewModel.swift
//  RSSFilter
//

import Foundation
import SwiftUI

@MainActor
class NewsViewModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    @Published var isProcessing = false
    @Published var selectedProvider: AIProvider = .appleIntelligence
    @Published var claudeAPIKey = ""
    @Published var openAIAPIKey = ""
    
    private var aiService: AIService?
    private let userDefaultsProviderKey = "selectedAIProvider"
    private let userDefaultsClaudeKey = "claudeAPIKey"
    private let userDefaultsOpenAIKey = "openAIAPIKey"
    
    init() {
        loadSettings()
        updateAIService()
    }
    
    // MARK: - AI Processing
    
    func processNewsItems(_ items: [NewsItem], smartFolders: [SmartFolder]) async {
        isProcessing = true
        updateAIService()
        
        guard let service = aiService else {
            print("No AI service available")
            isProcessing = false
            return
        }
        
        var processedItems: [NewsItem] = []
        
        // Process each news item
        for var item in items {
            // 1. Score quality
            do {
                let score = try await service.scoreQuality(newsItem: item)
                item.qualityScore = score
            } catch {
                print("Error scoring quality for \(item.title): \(error)")
            }
            
            // 2. Classify into smart folders
            do {
                let folderIDs = try await service.classifyIntoSmartFolders(newsItem: item, smartFolders: smartFolders)
                item.smartFolderIDs = folderIDs
            } catch {
                print("Error classifying \(item.title): \(error)")
            }
            
            processedItems.append(item)
        }
        
        // 3. Detect duplicates
        do {
            let duplicateGroups = try await service.detectDuplicates(newsItems: processedItems)
            
            for group in duplicateGroups {
                for var item in group.newsItems {
                    if let index = processedItems.firstIndex(where: { $0.id == item.id }) {
                        processedItems[index].duplicateGroupID = group.id
                    }
                }
            }
        } catch {
            print("Error detecting duplicates: \(error)")
        }
        
        newsItems = processedItems
        isProcessing = false
    }
    
    // MARK: - Filtering
    
    func getNewsItems(for feedID: UUID? = nil, smartFolderID: UUID? = nil) -> [NewsItem] {
        var filtered = newsItems
        
        if let feedID = feedID {
            filtered = filtered.filter { $0.feedID == feedID }
        }
        
        if let smartFolderID = smartFolderID {
            filtered = filtered.filter { $0.smartFolderIDs.contains(smartFolderID) }
        }
        
        // Sort by quality score (high to low), then by date
        return filtered.sorted { item1, item2 in
            let score1 = item1.qualityScore?.overallScore ?? 50
            let score2 = item2.qualityScore?.overallScore ?? 50
            
            if score1 != score2 {
                return score1 > score2
            }
            
            return (item1.pubDate ?? Date.distantPast) > (item2.pubDate ?? Date.distantPast)
        }
    }
    
    func getDuplicateGroups() -> [DuplicateGroup] {
        var groups: [UUID: [NewsItem]] = [:]
        
        for item in newsItems {
            if let groupID = item.duplicateGroupID {
                if groups[groupID] == nil {
                    groups[groupID] = []
                }
                groups[groupID]?.append(item)
            }
        }
        
        return groups.compactMap { (id, items) in
            items.count > 1 ? DuplicateGroup(id: id, newsItems: items) : nil
        }
    }
    
    // MARK: - Settings
    
    func updateProvider(_ provider: AIProvider) {
        selectedProvider = provider
        updateAIService()
        saveSettings()
    }
    
    func updateAPIKeys(claude: String, openAI: String) {
        claudeAPIKey = claude
        openAIAPIKey = openAI
        updateAIService()
        saveSettings()
    }
    
    private func updateAIService() {
        let apiKey: String
        switch selectedProvider {
        case .appleIntelligence:
            apiKey = ""
        case .claude:
            apiKey = claudeAPIKey
        case .openAI:
            apiKey = openAIAPIKey
        }
        
        aiService = AIServiceFactory.createService(provider: selectedProvider, apiKey: apiKey)
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: userDefaultsProviderKey)
        UserDefaults.standard.set(claudeAPIKey, forKey: userDefaultsClaudeKey)
        UserDefaults.standard.set(openAIAPIKey, forKey: userDefaultsOpenAIKey)
    }
    
    private func loadSettings() {
        if let providerString = UserDefaults.standard.string(forKey: userDefaultsProviderKey),
           let provider = AIProvider(rawValue: providerString) {
            selectedProvider = provider
        }
        
        claudeAPIKey = UserDefaults.standard.string(forKey: userDefaultsClaudeKey) ?? ""
        openAIAPIKey = UserDefaults.standard.string(forKey: userDefaultsOpenAIKey) ?? ""
    }
}
