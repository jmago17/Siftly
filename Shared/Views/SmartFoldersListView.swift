//
//  SmartFoldersListView.swift
//  RSS RAIder
//

import SwiftUI

struct SmartFoldersListView: View {
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @State private var showingAddFolder = false
    @State private var selectedNewsItem: NewsItem?
    @State private var showReadItems = false
    @State private var showingIntro = false
    @State private var readFilter: ReadFilter = .all
    @State private var showStarredOnly: Bool = false
    @State private var minScoreFilter: Int = 0
    @AppStorage("smartFoldersIntroSeen") private var introSeen = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if smartFoldersViewModel.smartFolders.isEmpty {
                ContentUnavailableView {
                    Label("No hay carpetas inteligentes", systemImage: "folder")
                } description: {
                    Text("Crea carpetas inteligentes para organizar tus noticias automáticamente")
                } actions: {
                    Button("Crear Carpeta") {
                        showingAddFolder = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(smartFoldersViewModel.smartFolders) { folder in
                        SmartFolderDetailView(
                            folder: folder,
                            newsItems: filteredNewsItems(for: folder),
                            smartFoldersViewModel: smartFoldersViewModel,
                            newsViewModel: newsViewModel,
                            feedsViewModel: feedsViewModel,
                            selectedNewsItem: $selectedNewsItem,
                            showReadItems: showReadItems
                        )
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            smartFoldersViewModel.deleteFolder(id: smartFoldersViewModel.smartFolders[index].id)
                        }
                    }

                    // Bottom padding to account for floating bar
                    Color.clear
                        .frame(height: 70)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            ArticleListBottomBar(
                readFilter: $readFilter,
                showStarredOnly: $showStarredOnly,
                minScoreFilter: $minScoreFilter
            )
        }
        .navigationTitle("Carpetas Inteligentes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFolder = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    showingIntro = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }

                Button {
                    showReadItems.toggle()
                } label: {
                    Image(systemName: showReadItems ? "eye" : "eye.slash")
                }
                .accessibilityLabel(showReadItems ? "Ocultar leídas" : "Mostrar leídas")
            }
        }
        .sheet(isPresented: $showingAddFolder) {
            AddSmartFolderView(smartFoldersViewModel: smartFoldersViewModel)
        }
        .sheet(isPresented: $showingIntro) {
            SmartFoldersIntroView()
        }
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
        .onAppear {
            // Update match counts when view appears
            smartFoldersViewModel.updateMatchCounts(newsItems: newsViewModel.newsItems)

            if !introSeen {
                introSeen = true
                showingIntro = true
            }
        }
    }

    private func shouldOpenInSafariReader(for item: NewsItem) -> Bool {
        #if os(iOS)
        return feedSettings[item.feedID]?.openInSafariReader ?? false
        #else
        return false
        #endif
    }

    private var feedSettings: [UUID: RSSFeed] {
        Dictionary(uniqueKeysWithValues: feedsViewModel.feeds.map { ($0.id, $0) })
    }

    private func filteredNewsItems(for folder: SmartFolder) -> [NewsItem] {
        var items = newsViewModel.getNewsItems(smartFolderID: folder.id)
            .filter { folder.matchesFilters(for: $0) }

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

        return items
    }
}

struct SmartFolderDetailView: View {
    let folder: SmartFolder
    let newsItems: [NewsItem]
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @Binding var selectedNewsItem: NewsItem?
    let showReadItems: Bool
    @State private var isExpanded = false
    @State private var showAll = false
    @State private var showingEditSheet = false

    private var feedSettings: [UUID: RSSFeed] {
        Dictionary(uniqueKeysWithValues: feedsViewModel.feeds.map { ($0.id, $0) })
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if newsItems.isEmpty {
                Text("No hay artículos en esta carpeta")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                    UnifiedNewsItemRow(
                        newsItem: item,
                        newsViewModel: newsViewModel,
                        feedSettings: feedSettings,
                        onTap: {
                            selectedNewsItem = item
                        }
                    )
                    .contextMenu {
                        Button {
                            newsViewModel.markAsRead(item.id, isRead: !item.isRead)
                        } label: {
                            Label(
                                item.isRead ? "Marcar como no leído" : "Marcar como leído",
                                systemImage: item.isRead ? "envelope.badge" : "envelope.open"
                            )
                        }

                        Button {
                            newsViewModel.markAsFavorite(item.id, isFavorite: !item.isFavorite)
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

                if filteredItems.count > maxPreviewCount {
                    Button(showAll ? "Mostrar menos" : "Mostrar \(filteredItems.count - maxPreviewCount) más") {
                        withAnimation {
                            showAll.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: folder.isEnabled ? "folder.fill" : "folder")
                            .foregroundColor(folder.isEnabled ? .accentColor : .gray)

                        Text(folder.name)
                            .font(.headline)
                    }

                    Text(folder.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if folder.matchCount > 0 {
                        Text("\(folder.matchCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }

                    Toggle("", isOn: Binding(
                        get: { folder.isEnabled },
                        set: { _ in smartFoldersViewModel.toggleFolder(id: folder.id) }
                    ))
                    .labelsHidden()
                }
            }
            .contextMenu {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Personalizar", systemImage: "slider.horizontal.3")
                }

                Button {
                    smartFoldersViewModel.toggleFolder(id: folder.id)
                } label: {
                    Label(
                        folder.isEnabled ? "Desactivar" : "Activar",
                        systemImage: folder.isEnabled ? "eye.slash" : "eye"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    smartFoldersViewModel.deleteFolder(id: folder.id)
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddSmartFolderView(smartFoldersViewModel: smartFoldersViewModel, smartFolder: folder)
        }
    }

    private var maxPreviewCount: Int {
        10
    }

    private var visibleItems: [NewsItem] {
        let sorted = filteredItems.sorted { lhs, rhs in
            if lhs.isRead != rhs.isRead {
                return !lhs.isRead
            }
            let lhsDate = lhs.pubDate ?? Date.distantPast
            let rhsDate = rhs.pubDate ?? Date.distantPast
            return lhsDate > rhsDate
        }

        if showAll {
            return sorted
        }

        return Array(sorted.prefix(maxPreviewCount))
    }

    private var filteredItems: [NewsItem] {
        newsItems.filter { showReadItems || !$0.isRead }
    }

    private func markAsReadAbove(index: Int) {
        let items = visibleItems
        for i in 0..<index {
            newsViewModel.markAsRead(items[i].id, isRead: true, notify: false)
        }
        newsViewModel.objectWillChange.send()
    }

    private func markAsReadBelow(index: Int) {
        let items = visibleItems
        for i in (index + 1)..<items.count {
            newsViewModel.markAsRead(items[i].id, isRead: true, notify: false)
        }
        newsViewModel.objectWillChange.send()
    }
}

#Preview {
    NavigationStack {
        SmartFoldersListView(
            smartFoldersViewModel: SmartFoldersViewModel(),
            newsViewModel: NewsViewModel(),
            feedsViewModel: FeedsViewModel(),
            smartFeedsViewModel: SmartFeedsViewModel()
        )
    }
}

struct SmartFoldersIntroView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("La app compara las palabras de la descripción con el título y el resumen de cada noticia.")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Usa 3-6 palabras clave separadas por comas.", systemImage: "checkmark.circle")
                        Label("Escribe en el idioma de tus feeds.", systemImage: "checkmark.circle")
                        Label("Evita frases genericas como \"News about ...\".", systemImage: "checkmark.circle")
                    }
                    .font(.subheadline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ejemplos")
                            .font(.headline)

                        Text("Politica: politica, gobierno, elecciones, parlamento")
                            .font(.subheadline)
                        Text("Economía: economia, mercados, bolsa, finanzas")
                            .font(.subheadline)
                        Text("Tecnología: tecnologia, software, hardware, inteligencia artificial")
                            .font(.subheadline)
                    }
                }
                .padding()
            }
            .navigationTitle("Cómo funciona")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Entendido") {
                        dismiss()
                    }
                }
            }
        }
    }
}
