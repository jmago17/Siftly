//
//  NewsListView.swift
//  RSS RAIder
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct NewsListView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var smartTagsViewModel: SmartTagsViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    let smartFeedOverride: SmartFeed?
    @State private var selectedFeedID: UUID?
    @State private var selectedSmartFolderID: UUID?
    @State private var selectedTagID: UUID?
    @State private var isRefreshing = false
    @State private var readFilter: ReadFilter = .unread
    @State private var minScoreFilter: Int = 0
    @State private var searchText = ""
    @State private var showStarredOnly: Bool = false
    @State private var sortOrder: ArticleSortOrder = .score
    @AppStorage("selectedSmartFeedID") private var selectedSmartFeedIDValue = ""

    init(
        newsViewModel: NewsViewModel,
        feedsViewModel: FeedsViewModel,
        smartFoldersViewModel: SmartFoldersViewModel,
        smartTagsViewModel: SmartTagsViewModel,
        smartFeedsViewModel: SmartFeedsViewModel,
        smartFeedOverride: SmartFeed? = nil
    ) {
        self.newsViewModel = newsViewModel
        self.feedsViewModel = feedsViewModel
        self.smartFoldersViewModel = smartFoldersViewModel
        self.smartTagsViewModel = smartTagsViewModel
        self.smartFeedsViewModel = smartFeedsViewModel
        self.smartFeedOverride = smartFeedOverride
    }

    var body: some View {
        Group {
            if newsViewModel.newsItems.isEmpty {
                ContentUnavailableView {
                    Label("No hay noticias", systemImage: "newspaper")
                } description: {
                    Text("Añade feeds RSS para comenzar a ver noticias")
                }
            } else {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        // Filter chips
                        if readFilter != .all || minScoreFilter > 0 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if readFilter != .all {
                                        FilterChip(
                                            text: readFilter.rawValue,
                                            systemImage: "book"
                                        ) {
                                            readFilter = .all
                                        }
                                    }

                                    if minScoreFilter > 0 {
                                        FilterChip(
                                            text: "Score ≥ \(minScoreFilter)",
                                            systemImage: "star"
                                        ) {
                                            minScoreFilter = 0
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            #if os(iOS)
                            .background(Color(uiColor: .systemBackground))
                            #else
                            .background(Color(nsColor: .windowBackgroundColor))
                            #endif
                        }

                        List {
                            ForEach(Array(filteredDeduplicatedNews.enumerated()), id: \.element.id) { index, item in
                                UnifiedArticleRow(
                                    newsItem: item,
                                    newsViewModel: newsViewModel,
                                    feedSettings: feedSettings
                                )
                                .contextMenu {
                                    Button {
                                        toggleReadStatus(for: item)
                                    } label: {
                                        Label(
                                            item.isRead ? "Marcar como no leído" : "Marcar como leído",
                                            systemImage: item.isRead ? "envelope.badge" : "envelope.open"
                                        )
                                    }

                                    Button {
                                        toggleFavorite(for: item)
                                    } label: {
                                        Label(
                                            item.isFavorite ? "Quitar de favoritos" : "Añadir a favoritos",
                                            systemImage: item.isFavorite ? "star.slash" : "star"
                                        )
                                    }

                                    Divider()

                                    Button {
                                        markAsReadAbove(index: index)
                                    } label: {
                                        Label("Marcar anteriores como leídos", systemImage: "arrow.up.circle")
                                    }

                                    Button {
                                        markAsReadBelow(index: index)
                                    } label: {
                                        Label("Marcar siguientes como leídos", systemImage: "arrow.down.circle")
                                    }
                                }
                            }

                            // Bottom padding to account for floating bar
                            Color.clear
                                .frame(height: 70)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .refreshable {
                            await refreshNews()
                        }
                    }

                    ArticleListBottomBar(
                        readFilter: $readFilter,
                        showStarredOnly: $showStarredOnly,
                        minScoreFilter: $minScoreFilter,
                        sortOrder: $sortOrder,
                        onMarkAllAsRead: {
                            markAllVisibleAsRead()
                        }
                    )
                }
            }
        }
        .navigationTitle(smartFeedTitle)
        #if os(iOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        #else
        .searchable(text: $searchText)
        #endif
        .overlay {
            if isRefreshing {
                ProgressView("Actualizando noticias...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        .task {
            // Load news on first appearance if empty
            if newsViewModel.newsItems.isEmpty && !isRefreshing {
                await refreshNews()
            }
        }
    }

    private var filteredDeduplicatedNews: [DeduplicatedNewsItem] {
        var news = newsViewModel.getDeduplicatedNewsItems(
            for: selectedFeedID,
            smartFolderID: selectedSmartFolderID,
            favoritesOnly: favoritesOnly
        )

        if let smartFeed = effectiveSmartFeed {
            news = applySmartFeedFilter(to: news, smartFeed: smartFeed)
        }

        news = applyMutedFeedFilter(to: news)

        // Filter by read status
        switch readFilter {
        case .all:
            break
        case .unread:
            news = news.filter { !$0.isRead }
        case .read:
            news = news.filter { $0.isRead }
        }

        // Filter by score
        if minScoreFilter > 0 {
            news = news.filter { item in
                guard let score = item.qualityScore?.overallScore else {
                    return false
                }
                return score >= minScoreFilter
            }
        }

        // Filter by starred
        if showStarredOnly {
            news = news.filter { $0.isFavorite }
        }

        // Filter by smart tag
        if let tagID = selectedTagID {
            news = news.filter { item in
                item.sources.contains { source in
                    newsViewModel.newsItems.first { $0.id == source.id }?.tagIDs.contains(tagID) ?? false
                }
            }
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            news = news.filter { item in
                item.title.lowercased().contains(query)
                || item.summary.lowercased().contains(query)
                || item.primarySource.feedName.lowercased().contains(query)
            }
        }

        // Apply sort order
        news = news.sorted { item1, item2 in
            switch sortOrder {
            case .score:
                let score1 = item1.qualityScore?.overallScore ?? 50
                let score2 = item2.qualityScore?.overallScore ?? 50
                if score1 != score2 {
                    return score1 > score2
                }
                return (item1.pubDate ?? Date.distantPast) > (item2.pubDate ?? Date.distantPast)
            case .chronological:
                return (item1.pubDate ?? Date.distantPast) > (item2.pubDate ?? Date.distantPast)
            }
        }

        if news.count > 40 {
            return Array(news.prefix(40))
        }

        return news
    }

    private var feedSettings: [UUID: RSSFeed] {
        Dictionary(uniqueKeysWithValues: feedsViewModel.feeds.map { ($0.id, $0) })
    }

    private var smartFeedTitle: String {
        if let selectedSmartFeed = effectiveSmartFeed {
            return "\(selectedSmartFeed.name) (\(filteredDeduplicatedNews.count))"
        }
        return "Todos los feeds (\(filteredDeduplicatedNews.count))"
    }

    private func refreshNews() async {
        isRefreshing = true

        // Fetch all feeds
        let newsItems = await feedsViewModel.fetchAllFeeds()

        // Process with AI if needed
        if !newsItems.isEmpty {
            await newsViewModel.processNewsItems(
                newsItems,
                smartFolders: smartFoldersViewModel.smartFolders,
                smartTags: smartTagsViewModel.smartTags,
                feeds: feedsViewModel.feeds
            )
            smartFoldersViewModel.updateMatchCounts(newsItems: newsViewModel.newsItems)
        }

        isRefreshing = false
    }

    private func applyMutedFeedFilter(to items: [DeduplicatedNewsItem]) -> [DeduplicatedNewsItem] {
        let mutedFeedIDs = Set(feedsViewModel.feeds.filter { $0.isMutedInNews }.map { $0.id })
        guard !mutedFeedIDs.isEmpty else { return items }

        return items.compactMap { item in
            let activeSources = item.sources.filter { !mutedFeedIDs.contains($0.feedID) }
            guard !activeSources.isEmpty else { return nil }
            if activeSources.count == item.sources.count {
                return item
            }
            return DeduplicatedNewsItem(
                id: item.id,
                title: item.title,
                summary: item.summary,
                pubDate: item.pubDate,
                sources: activeSources,
                smartFolderIDs: item.smartFolderIDs,
                author: item.author
            )
        }
    }

    private func applySmartFeedFilter(to items: [DeduplicatedNewsItem], smartFeed: SmartFeed) -> [DeduplicatedNewsItem] {
        let feedIDs = Set(smartFeed.feedIDs)

        return items.compactMap { item in
            let activeSources = feedIDs.isEmpty
                ? item.sources
                : item.sources.filter { feedIDs.contains($0.feedID) }
            guard !activeSources.isEmpty else { return nil }
            let candidate = activeSources.count == item.sources.count
                ? item
                : DeduplicatedNewsItem(
                    id: item.id,
                    title: item.title,
                    summary: item.summary,
                    pubDate: item.pubDate,
                    sources: activeSources,
                    smartFolderIDs: item.smartFolderIDs,
                    author: item.author
                )

            let content = "\(candidate.title) \(candidate.summary)"
            let author = candidate.author ?? candidate.primarySource.author
            let matches = smartFeed.filters.matches(
                content: content,
                url: candidate.primarySource.link,
                feedTitle: candidate.primarySource.feedName,
                author: author,
                date: candidate.pubDate
            )

            return matches ? candidate : nil
        }
    }

    private var selectedSmartFeedID: UUID? {
        get {
            UUID(uuidString: selectedSmartFeedIDValue)
        }
        nonmutating set {
            selectedSmartFeedIDValue = newValue?.uuidString ?? ""
        }
    }

    private var selectedSmartFeed: SmartFeed? {
        guard let selectedID = selectedSmartFeedID else { return nil }
        return smartFeedsViewModel.smartFeeds.first(where: { $0.id == selectedID })
    }

    private var effectiveSmartFeed: SmartFeed? {
        smartFeedOverride ?? selectedSmartFeed
    }

    private var favoritesOnly: Bool {
        effectiveSmartFeed?.kind == .favorites
    }

    // MARK: - Actions

    private func markAllVisibleAsRead() {
        for item in filteredDeduplicatedNews {
            for source in item.sources {
                newsViewModel.markAsRead(source.id, isRead: true, notify: false)
            }
        }
        newsViewModel.objectWillChange.send()
    }

    private func toggleReadStatus(for item: DeduplicatedNewsItem) {
        let newStatus = !item.isRead
        for source in item.sources {
            newsViewModel.markAsRead(source.id, isRead: newStatus, notify: false)
        }
        newsViewModel.objectWillChange.send()
    }

    private func toggleFavorite(for item: DeduplicatedNewsItem) {
        let newStatus = !item.isFavorite
        for source in item.sources {
            newsViewModel.markAsFavorite(source.id, isFavorite: newStatus, notify: false)
        }
        newsViewModel.objectWillChange.send()
    }

    private func markAsReadAbove(index: Int) {
        let items = filteredDeduplicatedNews
        for i in 0..<index {
            for source in items[i].sources {
                newsViewModel.markAsRead(source.id, isRead: true, notify: false)
            }
        }
        newsViewModel.objectWillChange.send()
    }

    private func markAsReadBelow(index: Int) {
        let items = filteredDeduplicatedNews
        for i in (index + 1)..<items.count {
            for source in items[i].sources {
                newsViewModel.markAsRead(source.id, isRead: true, notify: false)
            }
        }
        newsViewModel.objectWillChange.send()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let text: String
    let systemImage: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(text)
                .font(.caption)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .clipShape(Capsule())
    }
}

// MARK: - Bulk Actions View

struct BulkActionsView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    @Binding var threshold: Int
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Marca automáticamente como leídas todas las noticias cuya puntuación de calidad esté por debajo del umbral seleccionado.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Descripción")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Umbral de puntuación:")
                            Spacer()
                            Text("\(threshold)")
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                        }

                        Slider(value: Binding(
                            get: { Double(threshold) },
                            set: { threshold = Int($0) }
                        ), in: 0...100, step: 5)

                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Se marcarán como leídas las noticias con puntuación < \(threshold)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Configuración")
                }

                Section {
                    let affectedCount = newsViewModel.newsItems.filter { item in
                        guard let score = item.qualityScore?.overallScore else { return false }
                        return score < threshold && !item.isRead
                    }.count

                    if affectedCount > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("\(affectedCount) noticias serán marcadas como leídas")
                                .font(.callout)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("No hay noticias que cumplan este criterio")
                                .font(.callout)
                        }
                    }

                    Button {
                        showingConfirmation = true
                    } label: {
                        Label("Marcar como leídas", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(affectedCount == 0)
                } header: {
                    Text("Acción")
                }
            }
            .navigationTitle("Acciones Masivas")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "¿Marcar noticias como leídas?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Marcar como leídas", role: .destructive) {
                    newsViewModel.markAllAsRead(withScoreBelow: threshold)
                    dismiss()
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Esta acción no se puede deshacer")
            }
        }
    }

    private var scoreColor: Color {
        switch threshold {
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
        }
    }
}

#Preview {
    NavigationStack {
        NewsListView(
            newsViewModel: NewsViewModel(),
            feedsViewModel: FeedsViewModel(),
            smartFoldersViewModel: SmartFoldersViewModel(),
            smartFeedsViewModel: SmartFeedsViewModel(),
            smartTagsViewModel: SmartTagsViewModel()
        )
    }
}
