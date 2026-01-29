//
//  AIService.swift
//  RSS RAIder
//

import Foundation

protocol AIService {
    func scoreQuality(newsItem: NewsItem) async throws -> QualityScore
    func detectDuplicates(newsItems: [NewsItem]) async throws -> [DuplicateGroup]
    func classifyIntoSmartFolders(newsItem: NewsItem, smartFolders: [SmartFolder]) async throws -> [UUID]
}

protocol AIQuestionAnswering {
    func answerQuestion(question: String, context: String) async throws -> String
}

enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case rateLimited
    case networkError(Error)
    case notAvailable
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key no configurada"
        case .invalidResponse:
            return "Respuesta inválida del servicio AI"
        case .rateLimited:
            return "Límite de rate excedido"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .notAvailable:
            return "Servicio no disponible"
        }
    }
}
