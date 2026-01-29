//
//  AIServiceFactory.swift
//  RSS RAIder
//

import Foundation

class AIServiceFactory {
    static func createService(provider: AIProvider, apiKey: String = "") -> AIService {
        if #available(iOS 18.0, macOS 15.0, *) {
            return AppleIntelligenceService()
        } else {
            fatalError("Apple Intelligence requires iOS 18+ or macOS 15+")
        }
    }
}
