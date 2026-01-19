//
//  SmartFoldersViewModel.swift
//  RSS RAIder
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SmartFoldersViewModel: ObservableObject {
    @Published var smartFolders: [SmartFolder] = []
    @Published var iCloudSyncEnabled = true

    private let userDefaultsKey = "smartFolders"
    private let cloudSync = CloudSyncService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadFromDisk()

        // Add default folders if empty
        if smartFolders.isEmpty {
            addDefaultFolders()
        }

        setupCloudSync()

        // Sync from iCloud on first launch
        Task { @MainActor in
            syncFromCloud()
        }
    }

    private func setupCloudSync() {
        NotificationCenter.default.publisher(for: .cloudDataDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncFromCloud()
                }
            }
            .store(in: &cancellables)
    }

    func syncFromCloud() {
        guard iCloudSyncEnabled else { return }

        if let cloudFolders = cloudSync.loadSmartFolders() {
            mergeSmartFolders(cloudFolders)
        }
    }

    private func mergeSmartFolders(_ cloudFolders: [SmartFolder]) {
        var mergedFolders = smartFolders

        for cloudFolder in cloudFolders {
            if !mergedFolders.contains(where: { $0.id == cloudFolder.id }) {
                // Add new folder from cloud
                mergedFolders.append(cloudFolder)
            }
        }

        smartFolders = mergedFolders
        saveToDisk()
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

            // Sync to iCloud if enabled
            if iCloudSyncEnabled {
                cloudSync.saveSmartFolders(smartFolders)
            }
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
