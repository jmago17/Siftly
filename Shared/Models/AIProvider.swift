//
//  AIProvider.swift
//  RSS RAIder
//

import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case appleIntelligence = "Apple Intelligence"
    case claude = "Claude API"
    case openAI = "OpenAI API"
    
    var requiresAPIKey: Bool {
        switch self {
        case .appleIntelligence:
            return false
        case .claude, .openAI:
            return true
        }
    }
}
