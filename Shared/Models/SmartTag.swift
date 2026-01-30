//
//  SmartTag.swift
//  RSS RAIder
//

import Foundation
import SwiftUI

struct SmartTag: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var priority: Int // Higher = processed first by AI
    var isEnabled: Bool
    var colorName: String // System color name for UI

    init(name: String, description: String, priority: Int = 50, colorName: String = "blue") {
        self.id = UUID()
        self.name = name
        self.description = description
        self.priority = priority
        self.isEnabled = true
        self.colorName = colorName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case priority
        case isEnabled
        case colorName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 50
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        colorName = try container.decodeIfPresent(String.self, forKey: .colorName) ?? "blue"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(priority, forKey: .priority)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(colorName, forKey: .colorName)
    }

    var color: Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        default: return .blue
        }
    }

    static let availableColors = [
        "red", "orange", "yellow", "green", "mint", "teal",
        "cyan", "blue", "indigo", "purple", "pink", "brown"
    ]

    // Default tags
    static let defaultTags: [SmartTag] = [
        SmartTag(name: "Tecnología", description: "tecnología, software, hardware, inteligencia artificial, programación, gadgets, apps, startups", priority: 80, colorName: "blue"),
        SmartTag(name: "Política", description: "política, gobierno, elecciones, parlamento, congreso, senado, ley, legislación", priority: 90, colorName: "red"),
        SmartTag(name: "Economía", description: "economía, finanzas, mercados, bolsa, negocios, empresa, PIB, inflación, banco central", priority: 85, colorName: "green"),
        SmartTag(name: "Deportes", description: "deportes, fútbol, baloncesto, tenis, Fórmula 1, olimpiadas, liga, campeonato", priority: 70, colorName: "orange"),
        SmartTag(name: "Ciencia", description: "ciencia, investigación, estudio, científico, descubrimiento, NASA, espacio, medicina", priority: 75, colorName: "purple"),
        SmartTag(name: "Entretenimiento", description: "entretenimiento, cine, películas, series, música, celebridades, televisión, streaming", priority: 50, colorName: "pink")
    ]
}
