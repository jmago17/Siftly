//
//  CloudSyncService.swift
//  RSSFilter
//

import Foundation
import Combine

/// Service for syncing data via iCloud Key-Value Store
class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default
    private let feedsKey = "icloud_rssFeeds"
    private let smartFoldersKey = "icloud_smartFolders"

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
