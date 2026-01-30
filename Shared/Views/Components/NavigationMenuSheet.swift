//
//  NavigationMenuSheet.swift
//  RSS RAIder
//

import SwiftUI

struct NavigationMenuSheet: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var smartTagsViewModel: SmartTagsViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var feedsExpanded = true
    @State private var smartFoldersExpanded = true
    @State private var smartTagsExpanded = true
    @State private var smartFeedsExpanded = true
    @State private var smartFeedToEdit: SmartFeed?
    @State private var feedToEdit: RSSFeed?
    @AppStorage("selectedSmartFeedID") private var selectedSmartFeedIDValue = ""
    var showsCloseButton: Bool = true

    var body: some View {
        NavigationStack {
            #if os(iOS)
            ZStack {
                LiquidCrystalBackground()
                List {
                    feedsSection
                    smartFoldersSection
                    smartFeedsSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .refreshable {
                    await refreshFeeds()
                }
            }
            .navigationTitle("Navegación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    newsViewModel: newsViewModel,
                    smartFoldersViewModel: smartFoldersViewModel,
                    smartFeedsViewModel: smartFeedsViewModel,
                    feedsViewModel: feedsViewModel
                )
            }
            .sheet(item: $smartFeedToEdit) { smartFeed in
                SmartFeedEditorView(
                    smartFeedsViewModel: smartFeedsViewModel,
                    feedsViewModel: feedsViewModel,
                    smartFeed: smartFeed,
                    allowsEmptyFeeds: smartFeed.kind == .favorites
                )
            }
            .sheet(item: $feedToEdit) { feed in
                EditFeedNameView(
                    feed: feed,
                    feedsViewModel: feedsViewModel
                )
            }
            #else
            List {
                feedsSection
                smartFoldersSection
                smartFeedsSection
            }
            .navigationTitle("Navegación")
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    newsViewModel: newsViewModel,
                    smartFoldersViewModel: smartFoldersViewModel,
                    smartFeedsViewModel: smartFeedsViewModel,
                    feedsViewModel: feedsViewModel
                )
            }
            .sheet(item: $smartFeedToEdit) { smartFeed in
                SmartFeedEditorView(
                    smartFeedsViewModel: smartFeedsViewModel,
                    feedsViewModel: feedsViewModel,
                    smartFeed: smartFeed,
                    allowsEmptyFeeds: smartFeed.kind == .favorites
                )
            }
            .sheet(item: $feedToEdit) { feed in
                EditFeedNameView(
                    feed: feed,
                    feedsViewModel: feedsViewModel
                )
            }
            #endif
        }
    }

    private func markFeedAsRead(_ feed: RSSFeed) {
        for item in newsViewModel.newsItems where item.feedID == feed.id {
            newsViewModel.markAsRead(item.id, isRead: true, notify: false)
        }
        newsViewModel.objectWillChange.send()
    }

    private func toggleFeedMuted(_ feed: RSSFeed) {
        feedsViewModel.toggleFeedMuted(id: feed.id)
    }

    private var feedsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $feedsExpanded) {
                if feedFolderSections.isEmpty {
                    Text("Sin feeds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(feedFolderSections) { section in
                        DisclosureGroup {
                            if section.feeds.isEmpty {
                                Text("Sin feeds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(section.feeds) { feed in
                                    NavigationLink {
                                        FeedNewsView(
                                            feed: feed,
                                            newsViewModel: newsViewModel,
                                            feedsViewModel: feedsViewModel,
                                            smartFeedsViewModel: smartFeedsViewModel
                                        )
                                    } label: {
                                        HStack(spacing: 10) {
                                            FeedIconView(urlString: feed.url, size: 20)
                                            Text(feed.name)
                                                .lineLimit(1)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            feedsViewModel.deleteFeed(id: feed.id)
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            markFeedAsRead(feed)
                                        } label: {
                                            Label("Marcar leído", systemImage: "checkmark.circle")
                                        }
                                        .tint(.blue)
                                    }
                                    .contextMenu {
                                        Button {
                                            markFeedAsRead(feed)
                                        } label: {
                                            Label("Marcar todo como leído", systemImage: "checkmark.circle")
                                        }

                                        Button {
                                            feedToEdit = feed
                                        } label: {
                                            Label("Editar nombre", systemImage: "pencil")
                                        }

                                        Button {
                                            toggleFeedMuted(feed)
                                        } label: {
                                            Label(
                                                feed.isMutedInNews ? "Mostrar en noticias" : "Silenciar en noticias",
                                                systemImage: feed.isMutedInNews ? "bell" : "bell.slash"
                                            )
                                        }

                                        Divider()

                                        Button(role: .destructive) {
                                            feedsViewModel.deleteFeed(id: feed.id)
                                        } label: {
                                            Label("Eliminar feed", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)
                                Text(section.title)
                                Spacer()
                                if section.count > 0 {
                                    countPill(section.count)
                                }
                            }
                        }
                    }
                }
            } label: {
                sectionHeader(
                    title: "Feeds",
                    systemImage: "antenna.radiowaves.left.and.right",
                    tint: .secondary,
                    count: feedsViewModel.feeds.count
                )
            }
        }
    }

    private var smartFoldersSection: some View {
        Section {
            DisclosureGroup(isExpanded: $smartFoldersExpanded) {
                if enabledSmartFolders.isEmpty {
                    Text("No hay carpetas inteligentes activas")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(enabledSmartFolders) { folder in
                        NavigationLink {
                            SmartFolderNewsView(
                                folder: folder,
                                smartFoldersViewModel: smartFoldersViewModel,
                                newsViewModel: newsViewModel,
                                feedsViewModel: feedsViewModel,
                                smartFeedsViewModel: smartFeedsViewModel
                            )
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text(folder.name)
                                    .lineLimit(1)
                                Spacer()
                                if folder.matchCount > 0 {
                                    countPill(folder.matchCount, tint: .blue)
                                }
                            }
                        }
                    }
                }
            } label: {
                sectionHeader(
                    title: "Carpetas Inteligentes",
                    systemImage: "folder.fill",
                    tint: .blue,
                    count: enabledSmartFolders.count
                )
            }
        }
    }

    private var smartFeedsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $smartFeedsExpanded) {
                NavigationLink {
                    NewsListView(
                        newsViewModel: newsViewModel,
                        feedsViewModel: feedsViewModel,
                        smartFoldersViewModel: smartFoldersViewModel,
                        smartTagsViewModel: smartTagsViewModel,
                        smartFeedsViewModel: smartFeedsViewModel
                    )
                    .onAppear { selectedSmartFeedIDValue = "" }
                } label: {
                    SmartFeedRowView(
                        name: "Todos los feeds",
                        feedCount: feedsViewModel.feeds.count,
                        iconSystemName: "tray.full"
                    )
                }

                NavigationLink {
                    NewsListView(
                        newsViewModel: newsViewModel,
                        feedsViewModel: feedsViewModel,
                        smartFoldersViewModel: smartFoldersViewModel,
                        smartTagsViewModel: smartTagsViewModel,
                        smartFeedsViewModel: smartFeedsViewModel,
                        smartFeedOverride: favoritesSmartFeed
                    )
                    .onAppear { selectedSmartFeedIDValue = favoritesSmartFeed.id.uuidString }
                } label: {
                    SmartFeedRowView(
                        name: favoritesSmartFeed.name,
                        feedCount: favoritesFeedCount,
                        iconSystemName: favoritesSmartFeed.iconSystemName
                    )
                }
                .contextMenu {
                    Button {
                        smartFeedToEdit = favoritesSmartFeed
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                }

                if enabledSmartFeeds.isEmpty {
                    Text("No hay smart feeds adicionales")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(enabledSmartFeeds) { smartFeed in
                        NavigationLink {
                            NewsListView(
                                newsViewModel: newsViewModel,
                                feedsViewModel: feedsViewModel,
                                smartFoldersViewModel: smartFoldersViewModel,
                                smartTagsViewModel: smartTagsViewModel,
                                smartFeedsViewModel: smartFeedsViewModel,
                                smartFeedOverride: smartFeed
                            )
                            .onAppear { selectedSmartFeedIDValue = smartFeed.id.uuidString }
                        } label: {
                            SmartFeedRowView(
                                name: smartFeed.name,
                                feedCount: smartFeed.feedIDs.isEmpty ? feedsViewModel.feeds.count : smartFeed.feedIDs.count,
                                iconSystemName: smartFeed.iconSystemName
                            )
                        }
                        .contextMenu {
                            Button {
                                smartFeedToEdit = smartFeed
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                smartFeedsViewModel.deleteSmartFeed(id: smartFeed.id)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
            } label: {
                sectionHeader(
                    title: "Smart Feeds",
                    systemImage: "sparkles",
                    tint: .blue,
                    count: enabledSmartFeeds.count + 1
                )
            }
        }
    }

    private func sectionHeader(
        title: String,
        systemImage: String,
        tint: Color,
        count: Int?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(tint)
            Text(title)
                .font(.headline)
            Spacer()
            if let count, count > 0 {
                countPill(count)
            }
        }
    }

    private func countPill(_ count: Int, tint: Color = .secondary) -> some View {
        Text("\(count)")
            .font(.caption)
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.18), in: Capsule())
    }

    private var enabledSmartFolders: [SmartFolder] {
        smartFoldersViewModel.smartFolders.filter { $0.isEnabled }
    }

    private var enabledSmartFeeds: [SmartFeed] {
        smartFeedsViewModel.regularSmartFeeds
            .filter { $0.isEnabled }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var favoritesSmartFeed: SmartFeed {
        smartFeedsViewModel.favoritesSmartFeed
    }

    private var favoritesFeedCount: Int {
        favoritesSmartFeed.feedIDs.isEmpty ? feedsViewModel.feeds.count : favoritesSmartFeed.feedIDs.count
    }

    private func refreshFeeds() async {
        let newsItems = await feedsViewModel.fetchAllFeeds()
        guard !newsItems.isEmpty else { return }

        await newsViewModel.processNewsItems(
            newsItems,
            smartFolders: smartFoldersViewModel.smartFolders,
            smartTags: smartTagsViewModel.smartTags,
            feeds: feedsViewModel.feeds
        )
        smartFoldersViewModel.updateMatchCounts(newsItems: newsViewModel.newsItems)
    }

    private var feedFolderSections: [NavMenuFeedFolderSection] {
        let groupedFeedIDs = Set(feedsViewModel.feedFolders.flatMap { $0.feedIDs })
        let ungroupedFeeds = feedsViewModel.feeds.filter { !groupedFeedIDs.contains($0.id) }

        var sections: [NavMenuFeedFolderSection] = feedsViewModel.feedFolders.map { folder in
            let feeds = feedsViewModel.feeds.filter { folder.feedIDs.contains($0.id) }
            return NavMenuFeedFolderSection(id: folder.id, title: folder.name, feeds: feeds)
        }

        if !ungroupedFeeds.isEmpty {
            sections.append(NavMenuFeedFolderSection(
                id: NavMenuFeedFolderSection.ungroupedID,
                title: "Sin carpeta",
                feeds: ungroupedFeeds
            ))
        }

        return sections
    }
}

private struct NavMenuFeedFolderSection: Identifiable {
    let id: UUID
    let title: String
    let feeds: [RSSFeed]

    static let ungroupedID = UUID()

    var count: Int {
        feeds.count
    }
}

private struct LiquidCrystalBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        (colorScheme == .dark ? Color.black : Color.white)
            .ignoresSafeArea()
    }
}

// MARK: - Smart Folder News View (for navigation from menu)

struct SmartFolderNewsView: View {
    let folder: SmartFolder
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel

    @State private var readFilter: ReadFilter = .all
    @State private var showStarredOnly = false
    @State private var minScoreFilter: Int = 0
    @State private var selectedNewsItem: NewsItem?

    var body: some View {
        VStack(spacing: 0) {
            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("No hay artículos", systemImage: "newspaper")
                } description: {
                    Text("No hay artículos que coincidan con los filtros")
                }
            } else {
                List {
                    ForEach(filteredItems) { item in
                        UnifiedNewsItemRow(
                            newsItem: item,
                            newsViewModel: newsViewModel,
                            feedSettings: feedSettings,
                            onTap: {
                                selectedNewsItem = item
                            }
                        )
                    }
                }
            }

            ArticleListBottomBar(
                readFilter: $readFilter,
                showStarredOnly: $showStarredOnly,
                minScoreFilter: $minScoreFilter
            )
        }
        .navigationTitle(folder.name)
        .sheet(item: $selectedNewsItem) { item in
            Group {
                if shouldOpenInSafariReader(for: item),
                   let url = URL(string: item.link) {
                    SafariReaderView(url: url)
                } else {
                    ArticleReaderView(newsItem: item)
                }
            }
            #if os(iOS)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var newsItems: [NewsItem] {
        newsViewModel.getNewsItems(smartFolderID: folder.id)
            .filter { folder.matchesFilters(for: $0) }
    }

    private var filteredItems: [NewsItem] {
        var items = newsItems

        switch readFilter {
        case .all:
            break
        case .unread:
            items = items.filter { !$0.isRead }
        case .read:
            items = items.filter { $0.isRead }
        }

        if showStarredOnly {
            items = items.filter { $0.isFavorite }
        }

        if minScoreFilter > 0 {
            items = items.filter { item in
                guard let score = item.qualityScore?.overallScore else { return false }
                return score >= minScoreFilter
            }
        }

        return items.sorted { lhs, rhs in
            if lhs.isRead != rhs.isRead { return !lhs.isRead }
            let lhsDate = lhs.pubDate ?? Date.distantPast
            let rhsDate = rhs.pubDate ?? Date.distantPast
            return lhsDate > rhsDate
        }
    }

    private var feedSettings: [UUID: RSSFeed] {
        Dictionary(uniqueKeysWithValues: feedsViewModel.feeds.map { ($0.id, $0) })
    }

    private func shouldOpenInSafariReader(for item: NewsItem) -> Bool {
        #if os(iOS)
        return feedSettings[item.feedID]?.openInSafariReader ?? false
        #else
        return false
        #endif
    }
}

#Preview {
    NavigationMenuSheet(
        feedsViewModel: FeedsViewModel(),
        smartFoldersViewModel: SmartFoldersViewModel(),
        smartTagsViewModel: SmartTagsViewModel(),
        smartFeedsViewModel: SmartFeedsViewModel(),
        newsViewModel: NewsViewModel()
    )
}
