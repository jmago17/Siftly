//
//  FeedNewsView.swift
//  RSSFilter
//

import SwiftUI

struct FeedNewsView: View {
    let feed: RSSFeed
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel

    @State private var isRefreshing = false
    @State private var readFilter: ReadFilter = .all
    @State private var minScoreFilter: Int = 0
    @State private var showingFilters = false

    var body: some View {
        Group {
            if filteredNews.isEmpty {
                ContentUnavailableView {
                    Label("No hay noticias", systemImage: "newspaper")
                } description: {
                    Text("No hay noticias que coincidan con los filtros aplicados")
                }
            } else {
                List {
                    ForEach(filteredNews) { item in
                        DeduplicatedNewsRowView(newsItem: item, newsViewModel: newsViewModel)
                    }
                }
                .refreshable {
                    await refreshFeed()
                }
            }
        }
        .navigationTitle(feed.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingFilters = true
                    } label: {
                        Label("Filtros", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Divider()

                    Button {
                        markAllAsRead()
                    } label: {
                        Label("Marcar todas como leídas", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FilterSettingsView(
                readFilter: $readFilter,
                minScoreFilter: $minScoreFilter,
                feedName: feed.name
            )
        }
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
        var news = newsViewModel.getDeduplicatedNewsItems(for: feed.id)

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
                newsViewModel.markAsRead(source.id, isRead: true)
            }
        }
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
            feedsViewModel: FeedsViewModel()
        )
    }
}
