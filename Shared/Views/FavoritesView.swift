//
//  FavoritesView.swift
//  RSSFilter
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct FavoritesView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    @State private var readFilter: ReadFilter = .all
    @State private var minScoreFilter: Int = 0
    @State private var showingFilters = false

    var body: some View {
        Group {
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
                            DeduplicatedNewsRowView(newsItem: item, newsViewModel: newsViewModel)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        toggleFavorite(item)
                                    } label: {
                                        Label("Quitar favorito", systemImage: "star.slash.fill")
                                    }
                                    .tint(.yellow)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        toggleRead(item)
                                    } label: {
                                        Label(item.isRead ? "No leído" : "Leído", systemImage: item.isRead ? "envelope.open.fill" : "envelope.fill")
                                    }
                                    .tint(item.isRead ? .orange : .blue)
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Favoritos (\(filteredFavorites.count))")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FilterSettingsView(
                readFilter: $readFilter,
                minScoreFilter: $minScoreFilter,
                feedName: "favoritos"
            )
        }
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

    private func toggleRead(_ item: DeduplicatedNewsItem) {
        let newReadStatus = !item.isRead
        for source in item.sources {
            newsViewModel.markAsRead(source.id, isRead: newReadStatus)
        }
    }

    private func toggleFavorite(_ item: DeduplicatedNewsItem) {
        let newFavoriteStatus = !item.isFavorite
        for source in item.sources {
            newsViewModel.markAsFavorite(source.id, isFavorite: newFavoriteStatus)
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesView(newsViewModel: NewsViewModel())
    }
}
