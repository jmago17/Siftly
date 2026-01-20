//
//  FeedNewsView.swift
//  RSS RAIder
//

import SwiftUI

struct FeedNewsView: View {
    let feed: RSSFeed
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    var smartFoldersViewModel: SmartFoldersViewModel = SmartFoldersViewModel()

    @State private var isRefreshing = false
    @State private var readFilter: ReadFilter = .all
    @State private var minScoreFilter: Int = 0
    @State private var showStarredOnly: Bool = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            if filteredNews.isEmpty {
                ContentUnavailableView {
                    Label("No hay noticias", systemImage: "newspaper")
                } description: {
                    Text(emptyStateMessage)
                }
                actions: {
                    if hasActiveFilters {
                        Button("Restablecer filtros") {
                            readFilter = .all
                            minScoreFilter = 0
                            showStarredOnly = false
                            searchText = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List {
                    ForEach(filteredNews) { item in
                        UnifiedArticleRow(
                            newsItem: item,
                            newsViewModel: newsViewModel,
                            feedSettings: feedSettings
                        )
                    }
                }
                .refreshable {
                    await refreshFeed()
                }
            }

            ArticleListBottomBar(
                readFilter: $readFilter,
                showStarredOnly: $showStarredOnly,
                minScoreFilter: $minScoreFilter,
                feedsViewModel: feedsViewModel,
                smartFoldersViewModel: smartFoldersViewModel,
                smartFeedsViewModel: smartFeedsViewModel,
                newsViewModel: newsViewModel
            )
        }
        .navigationTitle(feed.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        #if os(iOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        #else
        .searchable(text: $searchText)
        #endif
        .overlay {
            if isRefreshing {
                ProgressView("Actualizando...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
    }

    private var filteredNews: [DeduplicatedNewsItem] {
        var news = unfilteredNews

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

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            news = news.filter { item in
                item.title.lowercased().contains(query)
                || item.summary.lowercased().contains(query)
            }
        }

        return news
    }

    private var unfilteredNews: [DeduplicatedNewsItem] {
        newsViewModel.getDeduplicatedNewsItems(for: feed.id)
    }

    private var hasActiveFilters: Bool {
        if readFilter != .all { return true }
        if minScoreFilter > 0 { return true }
        if showStarredOnly { return true }
        return !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyStateMessage: String {
        if hasActiveFilters {
            let total = unfilteredNews.count
            if total > 0 {
                return "Hay \(total) articulos, pero los filtros actuales los ocultan."
            }
            return "No hay noticias que coincidan con los filtros aplicados."
        }
        return "No hay noticias disponibles para este feed."
    }

    private func refreshFeed() async {
        isRefreshing = true

        do {
            _ = try await feedsViewModel.fetchFeed(feed)
            // Process with AI if needed (simplified for demo)
            isRefreshing = false
        } catch {
            print("Error refreshing feed: \(error)")
            isRefreshing = false
        }
    }

    private func markAllAsRead() {
        for item in filteredNews {
            // Mark all sources as read
            for source in item.sources {
                newsViewModel.markAsRead(source.id, isRead: true, notify: false)
            }
        }
        newsViewModel.objectWillChange.send()
    }

    private var feedSettings: [UUID: RSSFeed] {
        Dictionary(uniqueKeysWithValues: feedsViewModel.feeds.map { ($0.id, $0) })
    }
}

// MARK: - Filter Settings View

struct FilterSettingsView: View {
    @Binding var readFilter: ReadFilter
    @Binding var minScoreFilter: Int
    let feedName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Estado de lectura", selection: $readFilter) {
                        ForEach(ReadFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Lectura")
                } footer: {
                    Text("Filtra las noticias por su estado de lectura")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Puntuación mínima:")
                            Spacer()
                            Text("\(minScoreFilter)")
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                        }

                        Slider(value: Binding(
                            get: { Double(minScoreFilter) },
                            set: { minScoreFilter = Int($0) }
                        ), in: 0...100, step: 10)
                    }

                    if minScoreFilter > 0 {
                        Text("Solo se mostrarán noticias con puntuación ≥ \(minScoreFilter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Calidad")
                } footer: {
                    Text("Filtra noticias por su puntuación de calidad (0 = mostrar todas)")
                }

                Section {
                    Button(role: .destructive) {
                        readFilter = .all
                        minScoreFilter = 0
                    } label: {
                        Label("Restablecer filtros", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Filtros")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var scoreColor: Color {
        switch minScoreFilter {
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
        }
    }
}

#Preview {
    NavigationStack {
        FeedNewsView(
            feed: RSSFeed(name: "Example Feed", url: "https://example.com"),
            newsViewModel: NewsViewModel(),
            feedsViewModel: FeedsViewModel(),
            smartFeedsViewModel: SmartFeedsViewModel()
        )
    }
}
