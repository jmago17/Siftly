//
//  SmartFolder.swift
//  RSS RAIder
//

import Foundation

struct SmartFolder: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var isEnabled: Bool
    var matchCount: Int
    
    init(name: String, description: String) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.isEnabled = true
        self.matchCount = 0
    }
}
