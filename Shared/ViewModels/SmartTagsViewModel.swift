//
//  SmartTagsViewModel.swift
//  RSS RAIder
//

import Foundation
import Combine

@MainActor
class SmartTagsViewModel: ObservableObject {
    @Published var smartTags: [SmartTag] = []
    @Published var iCloudSyncEnabled = true

    private let storageKey = "smartTags"
    private let cloudSync = CloudSyncService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadFromDisk()
        observeCloudChanges()

        // Sync from cloud on first launch
        Task { @MainActor in
            syncFromCloud()
        }
    }

    // MARK: - CRUD Operations

    func addTag(_ tag: SmartTag) {
        smartTags.append(tag)
        saveToDisk()
    }

    func updateTag(_ tag: SmartTag) {
        if let index = smartTags.firstIndex(where: { $0.id == tag.id }) {
            smartTags[index] = tag
            saveToDisk()
        }
    }

    func deleteTag(id: UUID) {
        smartTags.removeAll { $0.id == id }
        saveToDisk()
    }

    func toggleTag(id: UUID) {
        if let index = smartTags.firstIndex(where: { $0.id == id }) {
            smartTags[index].isEnabled.toggle()
            saveToDisk()
        }
    }

    func updatePriority(id: UUID, priority: Int) {
        if let index = smartTags.firstIndex(where: { $0.id == id }) {
            smartTags[index].priority = max(0, min(100, priority))
            saveToDisk()
        }
    }

    func moveTags(from source: IndexSet, to destination: Int) {
        smartTags.move(fromOffsets: source, toOffset: destination)
        // Update priorities based on new order
        for (index, _) in smartTags.enumerated() {
            smartTags[index].priority = 100 - index * 10
        }
        saveToDisk()
    }

    /// Returns tags sorted by priority (highest first)
    var tagsByPriority: [SmartTag] {
        smartTags.filter { $0.isEnabled }.sorted { $0.priority > $1.priority }
    }

    /// Returns enabled tags
    var enabledTags: [SmartTag] {
        smartTags.filter { $0.isEnabled }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let tags = try? JSONDecoder().decode([SmartTag].self, from: data) {
            smartTags = tags
        } else {
            // First launch: use default tags
            smartTags = SmartTag.defaultTags
            saveToDisk()
        }
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(smartTags) {
            UserDefaults.standard.set(data, forKey: storageKey)

            // Sync to iCloud if enabled
            if iCloudSyncEnabled {
                cloudSync.saveSmartTags(smartTags)
            }
        }
    }

    // MARK: - iCloud Sync

    private func observeCloudChanges() {
        NotificationCenter.default.publisher(for: .cloudDataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncFromCloud()
            }
            .store(in: &cancellables)
    }

    func syncFromCloud() {
        guard iCloudSyncEnabled else { return }

        if let cloudTags = cloudSync.loadSmartTags() {
            // Merge cloud tags with local (cloud wins for conflicts)
            var mergedTags = smartTags
            for cloudTag in cloudTags {
                if let index = mergedTags.firstIndex(where: { $0.id == cloudTag.id }) {
                    mergedTags[index] = cloudTag
                } else {
                    mergedTags.append(cloudTag)
                }
            }
            smartTags = mergedTags
            saveToDisk()
        }
    }
}
