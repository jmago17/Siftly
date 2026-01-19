//
//  NewsListView.swift
//  RSSFilter
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
    @State private var selectedFeedID: UUID?
    @State private var selectedSmartFolderID: UUID?
    @State private var isRefreshing = false
    @State private var readFilter: ReadFilter = .all
    @State private var minScoreFilter: Int = 0
    @State private var showingFilters = false
    @State private var showingBulkActions = false
    @State private var bulkActionThreshold: Int = 50

    var body: some View {
        Group {
            if newsViewModel.newsItems.isEmpty {
                ContentUnavailableView {
                    Label("No hay noticias", systemImage: "newspaper")
                } description: {
                    Text("Añade feeds RSS para comenzar a ver noticias")
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
                        ForEach(filteredDeduplicatedNews) { item in
                            DeduplicatedNewsRowView(newsItem: item, newsViewModel: newsViewModel)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        toggleFavorite(item)
                                    } label: {
                                        Label(item.isFavorite ? "Quitar favorito" : "Favorito", systemImage: item.isFavorite ? "star.slash.fill" : "star.fill")
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
                    .refreshable {
                        await refreshNews()
                    }
                }
            }
        }
        .navigationTitle("Noticias (\(filteredDeduplicatedNews.count))")
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
                        showingBulkActions = true
                    } label: {
                        Label("Acciones masivas", systemImage: "checklist")
                    }

                    Divider()

                    if newsViewModel.isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button {
                            Task {
                                await refreshNews()
                            }
                        } label: {
                            Label("Actualizar", systemImage: "arrow.clockwise")
                        }
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
                feedName: "todas las noticias"
            )
        }
        .sheet(isPresented: $showingBulkActions) {
            BulkActionsView(
                newsViewModel: newsViewModel,
                threshold: $bulkActionThreshold
            )
        }
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
            smartFolderID: selectedSmartFolderID
        )

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

    private func refreshNews() async {
        isRefreshing = true

        // Fetch all feeds
        let newsItems = await feedsViewModel.fetchAllFeeds()

        // Process with AI if needed
        if !newsItems.isEmpty {
            await newsViewModel.processNewsItems(newsItems, smartFolders: smartFoldersViewModel.smartFolders)
            smartFoldersViewModel.updateMatchCounts(newsItems: newsViewModel.newsItems)
        }

        isRefreshing = false
    }

    private func toggleRead(_ item: DeduplicatedNewsItem) {
        let newReadStatus = !item.isRead
        // Mark all sources as read/unread
        for source in item.sources {
            newsViewModel.markAsRead(source.id, isRead: newReadStatus)
        }
        // Trigger refresh
        newsViewModel.objectWillChange.send()
    }

    private func toggleFavorite(_ item: DeduplicatedNewsItem) {
        let newFavoriteStatus = !item.isFavorite
        // Mark all sources as favorite/unfavorite
        for source in item.sources {
            newsViewModel.markAsFavorite(source.id, isFavorite: newFavoriteStatus)
        }
        // Trigger refresh
        newsViewModel.objectWillChange.send()
    }
}

struct DeduplicatedNewsRowView: View {
    let newsItem: DeduplicatedNewsItem
    @ObservedObject var newsViewModel: NewsViewModel
    @State private var selectedSource: NewsItemSource?
    @State private var showingSourceSelector = false
    @State private var refreshID = UUID()

    private var openInAppBrowser: Bool {
        UserDefaults.standard.bool(forKey: "openInAppBrowser")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(newsItem.title)
                .font(.headline)
                .lineLimit(2)

            // Summary
            if !newsItem.summary.isEmpty {
                Text(newsItem.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack {
                // Sources
                if newsItem.hasDuplicates {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                        Text("\(newsItem.sources.count) fuentes")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .onTapGesture {
                        showingSourceSelector = true
                    }
                } else {
                    Text(newsItem.primarySource.feedName)
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()

                // Date
                if let pubDate = newsItem.pubDate {
                    Text(pubDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Quality score indicator
                if let score = newsItem.qualityScore {
                    QualityBadgeView(score: score)
                }
            }

            // Warning badges
            HStack(spacing: 4) {
                if newsItem.qualityScore?.isClickbait == true {
                    Badge(text: "Clickbait", color: .orange)
                }
                if newsItem.qualityScore?.isSpam == true {
                    Badge(text: "Spam", color: .red)
                }
                if newsItem.qualityScore?.isAdvertisement == true {
                    Badge(text: "Anuncio", color: .purple)
                }
                if newsItem.hasDuplicates {
                    Badge(text: "Duplicado", color: .gray)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if openInAppBrowser {
                // Open in-app browser
                selectedSource = newsItem.primarySource
            } else {
                // Open in default browser
                openInDefaultBrowser(newsItem.primarySource.link)
                // Mark as read
                newsItem.primarySource.markAsRead(true)
            }
        }
        .sheet(item: $selectedSource) { source in
            ArticleReaderView(url: source.link, title: newsItem.title)
                .onDisappear {
                    // Mark as read when reader closes
                    source.markAsRead(true)
                    newsViewModel.objectWillChange.send()
                }
            #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
            #endif
        }
        .confirmationDialog("Seleccionar fuente", isPresented: $showingSourceSelector, titleVisibility: .visible) {
            ForEach(newsItem.sources) { source in
                Button(source.feedName) {
                    if openInAppBrowser {
                        selectedSource = source
                    } else {
                        openInDefaultBrowser(source.link)
                        source.markAsRead(true)
                    }
                }
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Elige la fuente que quieres leer")
        }
    }

    private func openInDefaultBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }

        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

struct QualityBadgeView: View {
    let score: QualityScore

    var body: some View {
        Text("\(score.overallScore)")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(scoreColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }

    private var scoreColor: Color {
        switch score.overallScore {
        case 80...100:
            return .green
        case 50...79:
            return .orange
        default:
            return .red
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
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
            smartFoldersViewModel: SmartFoldersViewModel()
        )
    }
}
