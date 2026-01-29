//
//  FavoritesView.swift
//  RSS RAIder
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct FavoritesView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    var smartFoldersViewModel: SmartFoldersViewModel = SmartFoldersViewModel()
    @State private var readFilter: ReadFilter = .all
    @State private var minScoreFilter: Int = 0
    @State private var showStarredOnly: Bool = true // Always true for Favorites
    @State private var sortOrder: ArticleSortOrder = .score

    var body: some View {
        ZStack(alignment: .bottom) {
            if filteredFavorites.isEmpty {
                ContentUnavailableView {
                    Label("No hay favoritos", systemImage: "star")
                } description: {
                    Text("Desliza a la derecha en una noticia para marcarla como favorita")
                }
            } else {
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
                        ForEach(Array(filteredFavorites.enumerated()), id: \.element.id) { index, item in
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
                }
            }

            ArticleListBottomBar(
                readFilter: $readFilter,
                showStarredOnly: $showStarredOnly,
                minScoreFilter: $minScoreFilter,
                sortOrder: $sortOrder,
                onMarkAllAsRead: {
                    markAllAsRead()
                }
            )
        }
        .navigationTitle("Favoritos (\(filteredFavorites.count))")
    }

    private var filteredFavorites: [DeduplicatedNewsItem] {
        var news = newsViewModel.getDeduplicatedNewsItems(favoritesOnly: true)

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

        return news
    }

    private var feedSettings: [UUID: RSSFeed] {
        Dictionary(uniqueKeysWithValues: feedsViewModel.feeds.map { ($0.id, $0) })
    }

    // MARK: - Actions

    private func markAllAsRead() {
        for item in filteredFavorites {
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
        let items = filteredFavorites
        for i in 0..<index {
            for source in items[i].sources {
                newsViewModel.markAsRead(source.id, isRead: true, notify: false)
            }
        }
        newsViewModel.objectWillChange.send()
    }

    private func markAsReadBelow(index: Int) {
        let items = filteredFavorites
        for i in (index + 1)..<items.count {
            for source in items[i].sources {
                newsViewModel.markAsRead(source.id, isRead: true, notify: false)
            }
        }
        newsViewModel.objectWillChange.send()
    }
}

#Preview {
    NavigationStack {
        FavoritesView(
            newsViewModel: NewsViewModel(),
            feedsViewModel: FeedsViewModel(),
            smartFeedsViewModel: SmartFeedsViewModel()
        )
    }
}
