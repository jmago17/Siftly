//
//  CloudSyncService.swift
//  RSS RAIder
//

import Foundation
import Combine

/// Service for syncing data via iCloud Key-Value Store
class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default
    private let feedsKey = "icloud_rssFeeds"
    private let feedFoldersKey = "icloud_feedFolders"
    private let smartFoldersKey = "icloud_smartFolders"
    private let smartFeedsKey = "icloud_smartFeeds"
    private let readStatesKey = "icloud_readStates"
    private let favoriteStatesKey = "icloud_favoriteStates"

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Observe changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )

        // Synchronize immediately
        store.synchronize()
    }

    // MARK: - Public Methods

    /// Save feeds to iCloud
    func saveFeeds(_ feeds: [RSSFeed]) {
        guard let data = try? JSONEncoder().encode(feeds) else {
            syncError = "Error encoding feeds"
            return
        }

        store.set(data, forKey: feedsKey)
        store.synchronize()
        lastSyncDate = Date()
    }

    /// Load feeds from iCloud
    func loadFeeds() -> [RSSFeed]? {
        guard let data = store.data(forKey: feedsKey) else {
            return nil
        }

        return try? JSONDecoder().decode([RSSFeed].self, from: data)
    }

    /// Save feed folders to iCloud
    func saveFeedFolders(_ folders: [FeedFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else {
            syncError = "Error encoding feed folders"
            return
        }

        store.set(data, forKey: feedFoldersKey)
        store.synchronize()
        lastSyncDate = Date()
    }

    /// Load feed folders from iCloud
    func loadFeedFolders() -> [FeedFolder]? {
        guard let data = store.data(forKey: feedFoldersKey) else {
            return nil
        }

        return try? JSONDecoder().decode([FeedFolder].self, from: data)
    }

    /// Save smart folders to iCloud
    func saveSmartFolders(_ folders: [SmartFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else {
            syncError = "Error encoding smart folders"
            return
        }

        store.set(data, forKey: smartFoldersKey)
        store.synchronize()
        lastSyncDate = Date()
    }

    /// Load smart folders from iCloud
    func loadSmartFolders() -> [SmartFolder]? {
        guard let data = store.data(forKey: smartFoldersKey) else {
            return nil
        }

        return try? JSONDecoder().decode([SmartFolder].self, from: data)
    }

    /// Save smart feeds to iCloud
    func saveSmartFeeds(_ feeds: [SmartFeed]) {
        guard let data = try? JSONEncoder().encode(feeds) else {
            syncError = "Error encoding smart feeds"
            return
        }

        store.set(data, forKey: smartFeedsKey)
        store.synchronize()
        lastSyncDate = Date()
    }

    /// Load smart feeds from iCloud
    func loadSmartFeeds() -> [SmartFeed]? {
        guard let data = store.data(forKey: smartFeedsKey) else {
            return nil
        }

        return try? JSONDecoder().decode([SmartFeed].self, from: data)
    }

    /// Save read states to iCloud
    func saveReadState(_ itemID: String, isRead: Bool) {
        var readStates = loadAllReadStates()
        readStates[itemID] = isRead

        guard let data = try? JSONEncoder().encode(readStates) else {
            syncError = "Error encoding read states"
            return
        }

        store.set(data, forKey: readStatesKey)
        store.synchronize()
        lastSyncDate = Date()
    }

    /// Load all read states from iCloud
    func loadAllReadStates() -> [String: Bool] {
        guard let data = store.data(forKey: readStatesKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    /// Get read state for specific item
    func getReadState(_ itemID: String) -> Bool? {
        let states = loadAllReadStates()
        return states[itemID]
    }

    /// Save favorite states to iCloud
    func saveFavoriteState(_ itemID: String, isFavorite: Bool) {
        var favoriteStates = loadAllFavoriteStates()
        favoriteStates[itemID] = isFavorite

        guard let data = try? JSONEncoder().encode(favoriteStates) else {
            syncError = "Error encoding favorite states"
            return
        }

        store.set(data, forKey: favoriteStatesKey)
        store.synchronize()
        lastSyncDate = Date()
    }

    /// Load all favorite states from iCloud
    func loadAllFavoriteStates() -> [String: Bool] {
        guard let data = store.data(forKey: favoriteStatesKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    /// Get favorite state for specific item
    func getFavoriteState(_ itemID: String) -> Bool? {
        let states = loadAllFavoriteStates()
        return states[itemID]
    }

    /// Manually trigger sync
    func sync() {
        isSyncing = true
        store.synchronize()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isSyncing = false
            self.lastSyncDate = Date()
        }
    }

    // MARK: - Private Methods

    @objc private func storeDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        // Handle different change reasons
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            // Data changed on server or initial sync
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cloudDataDidChange, object: nil)
            }

        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            syncError = "iCloud storage quota exceeded"

        case NSUbiquitousKeyValueStoreAccountChange:
            syncError = "iCloud account changed"

        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudDataDidChange = Notification.Name("cloudDataDidChange")
}
