//
//  SmartFeedsViewModel.swift
//  RSS RAIder
//

import Foundation
import Combine

@MainActor
class SmartFeedsViewModel: ObservableObject {
    @Published var smartFeeds: [SmartFeed] = []
    @Published var iCloudSyncEnabled = true

    private let userDefaultsKey = "smartFeeds"
    private let cloudSync = CloudSyncService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadFromDisk()
        ensureFavoritesFeed()
        WidgetExportStore.saveSmartFeeds(smartFeeds)
        setupCloudSync()

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

        if let cloudFeeds = cloudSync.loadSmartFeeds() {
            mergeSmartFeeds(cloudFeeds)
        }
    }

    private func mergeSmartFeeds(_ cloudFeeds: [SmartFeed]) {
        var mergedFeeds = smartFeeds

        for cloudFeed in cloudFeeds {
            if let index = mergedFeeds.firstIndex(where: { $0.id == cloudFeed.id }) {
                mergedFeeds[index] = cloudFeed
            } else {
                mergedFeeds.append(cloudFeed)
            }
        }

        smartFeeds = mergedFeeds
        ensureFavoritesFeed()
        saveToDisk()
    }

    // MARK: - CRUD

    func addSmartFeed(_ feed: SmartFeed) {
        smartFeeds.append(feed)
        saveToDisk()
    }

    func updateSmartFeed(_ feed: SmartFeed) {
        if let index = smartFeeds.firstIndex(where: { $0.id == feed.id }) {
            smartFeeds[index] = feed
            saveToDisk()
        }
    }

    func deleteSmartFeed(id: UUID) {
        if let feed = smartFeeds.first(where: { $0.id == id }), feed.kind == .favorites {
            return
        }
        smartFeeds.removeAll { $0.id == id }
        saveToDisk()
    }

    func toggleSmartFeed(id: UUID) {
        if let index = smartFeeds.firstIndex(where: { $0.id == id }) {
            smartFeeds[index].isEnabled.toggle()
            saveToDisk()
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(smartFeeds)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)

            if iCloudSyncEnabled {
                cloudSync.saveSmartFeeds(smartFeeds)
            }
            WidgetExportStore.saveSmartFeeds(smartFeeds)
        } catch {
            print("Error saving smart feeds: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            smartFeeds = try decoder.decode([SmartFeed].self, from: data)
        } catch {
            print("Error loading smart feeds: \(error)")
            smartFeeds = []
        }
    }

    var favoritesSmartFeed: SmartFeed {
        if let favorite = smartFeeds.first(where: { $0.kind == .favorites || $0.id == SmartFeed.favoritesID }) {
            return favorite
        }
        return SmartFeed(
            id: SmartFeed.favoritesID,
            name: "Favoritos",
            feedIDs: [],
            kind: .favorites,
            iconSystemName: "star.fill"
        )
    }

    var regularSmartFeeds: [SmartFeed] {
        smartFeeds.filter { $0.kind != .favorites && $0.id != SmartFeed.favoritesID }
    }

    private func ensureFavoritesFeed() {
        if let index = smartFeeds.firstIndex(where: { $0.kind == .favorites || $0.id == SmartFeed.favoritesID }) {
            smartFeeds[index].kind = .favorites
            smartFeeds[index].isEnabled = true
            if smartFeeds[index].iconSystemName.isEmpty {
                smartFeeds[index].iconSystemName = "star.fill"
            }
        } else {
            smartFeeds.insert(
                SmartFeed(
                    id: SmartFeed.favoritesID,
                    name: "Favoritos",
                    feedIDs: [],
                    kind: .favorites,
                    iconSystemName: "star.fill"
                ),
                at: 0
            )
        }
    }
}
