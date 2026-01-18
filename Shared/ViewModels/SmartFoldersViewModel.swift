//
//  SmartFoldersViewModel.swift
//  RSSFilter
//

import Foundation
import SwiftUI

@MainActor
class SmartFoldersViewModel: ObservableObject {
    @Published var smartFolders: [SmartFolder] = []
    
    private let userDefaultsKey = "smartFolders"
    
    init() {
        loadFromDisk()
        
        // Add default folders if empty
        if smartFolders.isEmpty {
            addDefaultFolders()
        }
    }
    
    // MARK: - CRUD Operations
    
    func addFolder(_ folder: SmartFolder) {
        smartFolders.append(folder)
        saveToDisk()
    }
    
    func updateFolder(_ folder: SmartFolder) {
        if let index = smartFolders.firstIndex(where: { $0.id == folder.id }) {
            smartFolders[index] = folder
            saveToDisk()
        }
    }
    
    func deleteFolder(id: UUID) {
        smartFolders.removeAll { $0.id == id }
        saveToDisk()
    }
    
    func toggleFolder(id: UUID) {
        if let index = smartFolders.firstIndex(where: { $0.id == id }) {
            smartFolders[index].isEnabled.toggle()
            saveToDisk()
        }
    }
    
    func updateMatchCounts(newsItems: [NewsItem]) {
        for index in smartFolders.indices {
            let folderID = smartFolders[index].id
            let count = newsItems.filter { $0.smartFolderIDs.contains(folderID) }.count
            smartFolders[index].matchCount = count
        }
        saveToDisk()
    }
    
    // MARK: - Default Folders
    
    private func addDefaultFolders() {
        let defaultFolders = [
            SmartFolder(name: "Tecnología", description: "Noticias sobre tecnología, software, hardware, inteligencia artificial, programación"),
            SmartFolder(name: "Política", description: "Noticias sobre política, elecciones, gobierno, partidos políticos"),
            SmartFolder(name: "Economía", description: "Noticias sobre economía, finanzas, bolsa, empresas, negocios"),
            SmartFolder(name: "Deportes", description: "Noticias sobre deportes, fútbol, baloncesto, tenis"),
            SmartFolder(name: "Ciencia", description: "Noticias sobre ciencia, investigación, descubrimientos, estudios")
        ]
        
        smartFolders = defaultFolders
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(smartFolders)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Error saving smart folders: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            smartFolders = try decoder.decode([SmartFolder].self, from: data)
        } catch {
            print("Error loading smart folders: \(error)")
            smartFolders = []
        }
    }
}
