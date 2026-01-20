//
//  FeedSource.swift
//  RSS RAIder
//

import Foundation

enum FeedSource: String, CaseIterable, Identifiable, Codable {
    case rss
    case feedbin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rss:
            return "RSS"
        case .feedbin:
            return "Feedbin"
        }
    }

    var description: String {
        switch self {
        case .rss:
            return "Usa los feeds RSS guardados en la app."
        case .feedbin:
            return "Usa Feedbin para cargar noticias desde tu cuenta."
        }
    }
}
