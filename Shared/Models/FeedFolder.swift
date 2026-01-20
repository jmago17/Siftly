//
//  FeedFolder.swift
//  RSS RAIder
//

import Foundation

struct FeedFolder: Codable, Identifiable {
    let id: UUID
    var name: String
    var feedIDs: [UUID]

    init(name: String, feedIDs: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.feedIDs = feedIDs
    }
}
