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

    var body: some View {
        VStack(spacing: 0) {
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
                        ForEach(filteredFavorites) { item in
                            UnifiedArticleRow(
                                newsItem: item,
                                newsViewModel: newsViewModel,
                                feedSettings: feedSettings
                            )
                        }
                    }
                }
            }

            ArticleListBottomBar(
                readFilter: $readFilter,
                showStarredOnly: $showStarredOnly,
                minScoreFilter: $minScoreFilter
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

        return news
    }

    private var feedSettings: [UUID: RSSFeed] {
        Dictionary(uniqueKeysWithValues: feedsViewModel.feeds.map { ($0.id, $0) })
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
