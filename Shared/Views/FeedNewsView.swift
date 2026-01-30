//
//  FeedNewsView.swift
//  RSS RAIder
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
    @State private var sortOrder: ArticleSortOrder = .score

    var body: some View {
        ZStack(alignment: .bottom) {
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
                    ForEach(Array(filteredNews.enumerated()), id: \.element.id) { index, item in
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
                    await refreshFeed()
                }
            }

            ArticleListBottomBar(
                readFilter: $readFilter,
                showStarredOnly: $showStarredOnly,
                minScoreFilter: $minScoreFilter,
                sortOrder: $sortOrder,
                searchText: $searchText,
                onMarkAllAsRead: {
                    markAllAsRead()
                }
            )
        }
        .navigationTitle(feed.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    shareFeedURL()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
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
        let items = filteredNews
        for i in 0..<index {
            for source in items[i].sources {
                newsViewModel.markAsRead(source.id, isRead: true, notify: false)
            }
        }
        newsViewModel.objectWillChange.send()
    }

    private func markAsReadBelow(index: Int) {
        let items = filteredNews
        for i in (index + 1)..<items.count {
            for source in items[i].sources {
                newsViewModel.markAsRead(source.id, isRead: true, notify: false)
            }
        }
        newsViewModel.objectWillChange.send()
    }

    private var feedSettings: [UUID: RSSFeed] {
        Dictionary(uniqueKeysWithValues: feedsViewModel.feeds.map { ($0.id, $0) })
    }

    private func shareFeedURL() {
        guard let url = URL(string: feed.url) else { return }
        #if os(iOS)
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        guard let presenter = topViewController() else { return }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
        #elseif os(macOS)
        let picker = NSSharingServicePicker(items: [url])
        if let keyWindow = NSApplication.shared.keyWindow, let contentView = keyWindow.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
        #endif
    }

    #if os(iOS)
    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
        return topViewController(from: keyWindow?.rootViewController)
    }

    private func topViewController(from controller: UIViewController?) -> UIViewController? {
        if let navigation = controller as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = controller?.presentedViewController {
            return topViewController(from: presented)
        }
        return controller
    }
    #endif
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
