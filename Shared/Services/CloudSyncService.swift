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
    private let smartTagsKey = "icloud_smartTags"
    private let smartFeedsKey = "icloud_smartFeeds"
    private let readStatesKey = "icloud_readStates"
    private let favoriteStatesKey = "icloud_favoriteStates"

    // Cached states to avoid repeated iCloud reads
    private var cachedReadStates: [String: Bool]?
    private var cachedFavoriteStates: [String: Bool]?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 10 // Refresh cache every 10 seconds

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

        // Load initial cache
        refreshCache()
    }

    // MARK: - Cache Management

    private func refreshCache() {
        cachedReadStates = loadAllReadStatesFromStore()
        cachedFavoriteStates = loadAllFavoriteStatesFromStore()
        cacheTimestamp = Date()
    }

    private func isCacheValid() -> Bool {
        guard let timestamp = cacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < cacheDuration
    }

    func invalidateCache() {
        cachedReadStates = nil
        cachedFavoriteStates = nil
        cacheTimestamp = nil
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

    /// Save smart tags to iCloud
    func saveSmartTags(_ tags: [SmartTag]) {
        guard let data = try? JSONEncoder().encode(tags) else {
            syncError = "Error encoding smart tags"
            return
        }

        store.set(data, forKey: smartTagsKey)
        store.synchronize()
        lastSyncDate = Date()
    }

    /// Load smart tags from iCloud
    func loadSmartTags() -> [SmartTag]? {
        guard let data = store.data(forKey: smartTagsKey) else {
            return nil
        }

        return try? JSONDecoder().decode([SmartTag].self, from: data)
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

    // MARK: - Read States (with caching)

    /// Save read state to iCloud and update cache
    func saveReadState(_ itemID: String, isRead: Bool) {
        // Update cache immediately
        if cachedReadStates == nil {
            cachedReadStates = [:]
        }
        cachedReadStates?[itemID] = isRead

        // Save to iCloud in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var readStates = self.loadAllReadStatesFromStore()
            readStates[itemID] = isRead

            // Trim old entries to stay under iCloud limits (keep most recent 5000)
            if readStates.count > 5000 {
                let sortedKeys = readStates.keys.sorted()
                let keysToRemove = sortedKeys.prefix(readStates.count - 5000)
                for key in keysToRemove {
                    readStates.removeValue(forKey: key)
                }
            }

            guard let data = try? JSONEncoder().encode(readStates) else {
                DispatchQueue.main.async {
                    self.syncError = "Error encoding read states"
                }
                return
            }

            self.store.set(data, forKey: self.readStatesKey)
            self.store.synchronize()
            DispatchQueue.main.async {
                self.lastSyncDate = Date()
            }
        }
    }

    /// Load all read states from iCloud store (internal)
    private func loadAllReadStatesFromStore() -> [String: Bool] {
        guard let data = store.data(forKey: readStatesKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    /// Load all read states (cached)
    func loadAllReadStates() -> [String: Bool] {
        if !isCacheValid() {
            refreshCache()
        }
        return cachedReadStates ?? [:]
    }

    /// Get read state for specific item (cached)
    func getReadState(_ itemID: String) -> Bool? {
        if !isCacheValid() {
            refreshCache()
        }
        return cachedReadStates?[itemID]
    }

    // MARK: - Favorite States (with caching)

    /// Save favorite state to iCloud and update cache
    func saveFavoriteState(_ itemID: String, isFavorite: Bool) {
        // Update cache immediately
        if cachedFavoriteStates == nil {
            cachedFavoriteStates = [:]
        }
        cachedFavoriteStates?[itemID] = isFavorite

        // Save to iCloud in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var favoriteStates = self.loadAllFavoriteStatesFromStore()
            favoriteStates[itemID] = isFavorite

            // Trim old entries to stay under iCloud limits
            if favoriteStates.count > 2000 {
                let sortedKeys = favoriteStates.keys.sorted()
                let keysToRemove = sortedKeys.prefix(favoriteStates.count - 2000)
                for key in keysToRemove {
                    favoriteStates.removeValue(forKey: key)
                }
            }

            guard let data = try? JSONEncoder().encode(favoriteStates) else {
                DispatchQueue.main.async {
                    self.syncError = "Error encoding favorite states"
                }
                return
            }

            self.store.set(data, forKey: self.favoriteStatesKey)
            self.store.synchronize()
            DispatchQueue.main.async {
                self.lastSyncDate = Date()
            }
        }
    }

    /// Load all favorite states from iCloud store (internal)
    private func loadAllFavoriteStatesFromStore() -> [String: Bool] {
        guard let data = store.data(forKey: favoriteStatesKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    /// Load all favorite states (cached)
    func loadAllFavoriteStates() -> [String: Bool] {
        if !isCacheValid() {
            refreshCache()
        }
        return cachedFavoriteStates ?? [:]
    }

    /// Get favorite state for specific item (cached)
    func getFavoriteState(_ itemID: String) -> Bool? {
        if !isCacheValid() {
            refreshCache()
        }
        return cachedFavoriteStates?[itemID]
    }

    /// Manually trigger sync
    func sync() {
        isSyncing = true
        invalidateCache()
        store.synchronize()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshCache()
            self?.isSyncing = false
            self?.lastSyncDate = Date()
        }
    }

    // MARK: - Bulk Operations

    /// Merge local read states with cloud (for initial sync)
    func mergeReadStatesFromLocal(_ localStates: [String: Bool]) {
        var cloudStates = loadAllReadStatesFromStore()

        // Merge: local wins if cloud doesn't have the item
        for (itemID, isRead) in localStates {
            if cloudStates[itemID] == nil {
                cloudStates[itemID] = isRead
            }
        }

        // Update cache
        cachedReadStates = cloudStates
        cacheTimestamp = Date()

        // Save merged states
        guard let data = try? JSONEncoder().encode(cloudStates) else {
            syncError = "Error encoding merged read states"
            return
        }

        store.set(data, forKey: readStatesKey)
        store.synchronize()
        lastSyncDate = Date()
    }

    /// Merge local favorite states with cloud (for initial sync)
    func mergeFavoriteStatesFromLocal(_ localStates: [String: Bool]) {
        var cloudStates = loadAllFavoriteStatesFromStore()

        // Merge: local wins if cloud doesn't have the item
        for (itemID, isFavorite) in localStates {
            if cloudStates[itemID] == nil {
                cloudStates[itemID] = isFavorite
            }
        }

        // Update cache
        cachedFavoriteStates = cloudStates
        cacheTimestamp = Date()

        // Save merged states
        guard let data = try? JSONEncoder().encode(cloudStates) else {
            syncError = "Error encoding merged favorite states"
            return
        }

        store.set(data, forKey: favoriteStatesKey)
        store.synchronize()
        lastSyncDate = Date()
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
            // Data changed on server or initial sync - invalidate cache
            DispatchQueue.main.async { [weak self] in
                self?.invalidateCache()
                self?.refreshCache()
                NotificationCenter.default.post(name: .cloudDataDidChange, object: nil)
            }

        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            DispatchQueue.main.async { [weak self] in
                self?.syncError = "iCloud storage quota exceeded"
            }

        case NSUbiquitousKeyValueStoreAccountChange:
            DispatchQueue.main.async { [weak self] in
                self?.invalidateCache()
                self?.syncError = "iCloud account changed"
            }

        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudDataDidChange = Notification.Name("cloudDataDidChange")
}
