//
//  FeedsListView.swift
//  RSS RAIder
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct FeedsListView: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var smartTagsViewModel: SmartTagsViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @AppStorage("selectedSmartFeedID") private var selectedSmartFeedIDValue = ""
    @State private var showingAddFeed = false
    @State private var showingAddFolder = false
    @State private var showingAddSmartFeed = false
    @State private var feedToMove: RSSFeed?
    @State private var showingMoveDialog = false
    @State private var feedToRename: RSSFeed?
    @State private var smartFeedToEdit: SmartFeed?
    @State private var folderToEdit: FeedFolder?
    #if os(iOS)
    @State private var feedForFeedbin: RSSFeed?
    #endif
    @State private var folderExpanded: [UUID: Bool] = [:]
    @State private var smartFeedsExpanded = true
    @State private var foldersExpanded = true
    @State private var searchText = ""
    @State private var showingSearch = false

    private var sortedSmartFeeds: [SmartFeed] {
        smartFeedsViewModel.smartFeeds.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind == .favorites
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        contentView
        .navigationTitle("Feeds")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }

                Menu {
                    Button {
                        showingAddSmartFeed = true
                    } label: {
                        Label("Nuevo Smart Feed", systemImage: "sparkles")
                    }

                    Button {
                        showingAddFeed = true
                    } label: {
                        Label("Añadir Feed", systemImage: "plus")
                    }

                    Button {
                        showingAddFolder = true
                    } label: {
                        Label("Nueva carpeta", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Task {
                        _ = await feedsViewModel.fetchAllFeeds()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(feedsViewModel.isLoading)
            }
        }
        .sheet(isPresented: $showingAddFeed) {
            AddFeedView(feedsViewModel: feedsViewModel)
        }
        .sheet(isPresented: $showingAddFolder) {
            AddFeedFolderView(feedsViewModel: feedsViewModel)
        }
        .sheet(isPresented: $showingAddSmartFeed) {
            SmartFeedEditorView(
                smartFeedsViewModel: smartFeedsViewModel,
                feedsViewModel: feedsViewModel,
                smartFeed: nil,
                allowsEmptyFeeds: false
            )
        }
        .sheet(item: $feedToRename) { feed in
            EditFeedNameView(feed: feed, feedsViewModel: feedsViewModel)
        }
        .sheet(item: $smartFeedToEdit) { smartFeed in
            SmartFeedEditorView(
                smartFeedsViewModel: smartFeedsViewModel,
                feedsViewModel: feedsViewModel,
                smartFeed: smartFeed,
                allowsEmptyFeeds: smartFeed.kind == .favorites
            )
        }
        .sheet(item: $folderToEdit) { folder in
            EditFeedFolderView(folder: folder, feedsViewModel: feedsViewModel)
        }
        #if os(iOS)
        .sheet(item: $feedForFeedbin) { feed in
            FeedbinDebugView(feed: feed)
        }
        #endif
        .confirmationDialog("Mover a carpeta", isPresented: $showingMoveDialog, titleVisibility: .visible, presenting: feedToMove) { feed in
            Button("Sin carpeta") {
                feedsViewModel.assignFeed(feed.id, to: nil)
            }

            ForEach(feedsViewModel.feedFolders) { folder in
                Button(folder.name) {
                    feedsViewModel.assignFeed(feed.id, to: folder.id)
                }
            }

            Button("Cancelar", role: .cancel) { }
        } message: { feed in
            Text("Selecciona una carpeta para \(feed.name)")
        }
        .overlay {
            if feedsViewModel.isLoading {
                ProgressView("Actualizando feeds...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        #if os(iOS)
        .searchable(text: $searchText, isPresented: $showingSearch, placement: .navigationBarDrawer(displayMode: .always))
        #else
        .searchable(text: $searchText, isPresented: $showingSearch)
        #endif
    }

    @ViewBuilder
    private var contentView: some View {
        if feedsViewModel.feeds.isEmpty && smartFeedsViewModel.regularSmartFeeds.isEmpty {
            emptyStateView
        } else {
            feedsListView
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No hay feeds RSS", systemImage: "antenna.radiowaves.left.and.right")
        } description: {
            Text("Añade feeds RSS para comenzar a ver noticias")
        } actions: {
            Button("Añadir Feed") {
                showingAddFeed = true
            }
            .buttonStyle(.borderedProminent)

            Button("Nueva carpeta") {
                showingAddFolder = true
            }
        }
    }

    private var feedsListView: some View {
        List {
            smartFeedsGroup
            foldersGroup
        }
        .refreshable {
            _ = await feedsViewModel.fetchAllFeeds()
        }
    }

    @ViewBuilder
    private var smartFeedsGroup: some View {
        DisclosureGroup(isExpanded: $smartFeedsExpanded) {
            smartFeedsContent
        } label: {
            smartFeedsHeader
        }
    }

    @ViewBuilder
    private var smartFeedsContent: some View {
        NavigationLink {
            NewsListView(
                newsViewModel: newsViewModel,
                feedsViewModel: feedsViewModel,
                smartFoldersViewModel: smartFoldersViewModel,
                smartTagsViewModel: smartTagsViewModel,
                smartFeedsViewModel: smartFeedsViewModel
            )
        } label: {
            SmartFeedRowView(
                name: "Todos los feeds",
                feedCount: feedsViewModel.feeds.count,
                iconSystemName: "tray.full"
            )
        }
        .simultaneousGesture(TapGesture().onEnded {
            selectedSmartFeedIDValue = ""
        })

        if sortedSmartFeeds.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("No hay smart feeds")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Crear smart feed") {
                    showingAddSmartFeed = true
                }
                .font(.caption)
            }
            .padding(.vertical, 4)
        } else {
            ForEach(sortedSmartFeeds) { smartFeed in
                NavigationLink {
                    NewsListView(
                        newsViewModel: newsViewModel,
                        feedsViewModel: feedsViewModel,
                        smartFoldersViewModel: smartFoldersViewModel,
                        smartTagsViewModel: smartTagsViewModel,
                        smartFeedsViewModel: smartFeedsViewModel,
                        smartFeedOverride: smartFeed
                    )
                } label: {
                    SmartFeedRowView(
                        name: smartFeed.name,
                        feedCount: smartFeed.feedIDs.isEmpty ? feedsViewModel.feeds.count : smartFeed.feedIDs.count,
                        iconSystemName: smartFeed.iconSystemName
                    )
                }
                .simultaneousGesture(TapGesture().onEnded {
                    selectedSmartFeedIDValue = smartFeed.id.uuidString
                })
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if smartFeed.kind != .favorites {
                        Button(role: .destructive) {
                            smartFeedsViewModel.deleteSmartFeed(id: smartFeed.id)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }

                    Button {
                        smartFeedToEdit = smartFeed
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
    }

    private var smartFeedsHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.blue)
            Text("Smart Feeds")
            Spacer()
            if !sortedSmartFeeds.isEmpty {
                Text("\(sortedSmartFeeds.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var foldersGroup: some View {
        DisclosureGroup(isExpanded: $foldersExpanded) {
            if folderSections.isEmpty {
                Text("No hay carpetas")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(folderSections) { section in
                    folderSectionView(section)
                }
            }
        } label: {
            foldersHeader
        }
    }

    private var foldersHeader: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundColor(.orange)
            Text("Carpetas")
            Spacer()
            if !folderSections.isEmpty {
                Text("\(folderSections.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func folderSectionView(_ section: FeedFolderSection) -> some View {
        DisclosureGroup(isExpanded: bindingForFolder(section.id)) {
            if section.feeds.isEmpty {
                Text("Sin feeds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(section.feeds) { feed in
                    feedRow(feed)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        feedsViewModel.deleteFeed(id: section.feeds[index].id)
                    }
                }
            }
        } label: {
            HStack {
                Text(section.title)
                Spacer()
                if section.count > 0 {
                    Text("\(section.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let folder = folderForSection(section) {
                Button {
                    folderToEdit = folder
                } label: {
                    Label("Personalizar", systemImage: "slider.horizontal.3")
                }
                .tint(.orange)
            }
        }
    }

    private func bindingForFolder(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { folderExpanded[id] ?? true },
            set: { folderExpanded[id] = $0 }
        )
    }

    private func feedRow(_ feed: RSSFeed) -> some View {
        NavigationLink {
            FeedNewsView(
                feed: feed,
                newsViewModel: newsViewModel,
                feedsViewModel: feedsViewModel,
                smartFeedsViewModel: smartFeedsViewModel
            )
        } label: {
            FeedDetailRowView(feed: feed)
        }
        .contextMenu {
            Button {
                shareFeed(feed)
            } label: {
                Label("Compartir", systemImage: "square.and.arrow.up")
            }

            #if os(iOS)
            Button {
                feedForFeedbin = feed
            } label: {
                Label("Feedbin", systemImage: "ladybug")
            }
            #endif
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                feedsViewModel.deleteFeed(id: feed.id)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }

            #if os(iOS)
            Button {
                feedForFeedbin = feed
            } label: {
                Label("Feedbin", systemImage: "ladybug")
            }
            .tint(.teal)
            #endif

            Button {
                shareFeed(feed)
            } label: {
                Label("Compartir", systemImage: "square.and.arrow.up")
            }
            .tint(.green)

            Button {
                feedToMove = feed
                showingMoveDialog = true
            } label: {
                Label("Mover", systemImage: "folder")
            }
            .tint(.blue)

            Button {
                feedToRename = feed
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }

    private func shareFeed(_ feed: RSSFeed) {
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

    private func folderForSection(_ section: FeedFolderSection) -> FeedFolder? {
        guard section.id != FeedFolderSection.ungroupedID else { return nil }
        return feedsViewModel.feedFolders.first { $0.id == section.id }
    }

    private var folderSections: [FeedFolderSection] {
        let groupedFeedIDs = Set(feedsViewModel.feedFolders.flatMap { $0.feedIDs })
        let allFeeds = filteredFeeds
        let ungroupedFeeds = allFeeds.filter { !groupedFeedIDs.contains($0.id) }

        var sections: [FeedFolderSection] = feedsViewModel.feedFolders.map { folder in
            let feeds = allFeeds.filter { folder.feedIDs.contains($0.id) }
            return FeedFolderSection(id: folder.id, title: folder.name, feeds: feeds)
        }

        if !ungroupedFeeds.isEmpty {
            sections.append(FeedFolderSection(id: FeedFolderSection.ungroupedID, title: "Sin carpeta", feeds: ungroupedFeeds))
        }

        return sections
    }

    private var filteredFeeds: [RSSFeed] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return feedsViewModel.feeds }
        let lowered = query.lowercased()
        return feedsViewModel.feeds.filter { feed in
            feed.name.lowercased().contains(lowered)
            || feed.url.lowercased().contains(lowered)
        }
    }
}

private struct FeedFolderSection: Identifiable {
    let id: UUID
    let title: String
    let feeds: [RSSFeed]

    static let ungroupedID = UUID()

    var count: Int {
        feeds.count
    }
}

struct FeedDetailRowView: View {
    let feed: RSSFeed

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FeedIconView(urlString: feed.url)

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.name)
                    .font(.headline)

                if let error = feed.lastFetchError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct SmartFeedRowView: View {
    let name: String
    let feedCount: Int
    let iconSystemName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconSystemName)
                .foregroundColor(.blue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)

                Text("\(feedCount) feeds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("AI")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct FeedIconView: View {
    let urlString: String
    var size: CGFloat = 28

    private var iconURL: URL? {
        guard let components = URLComponents(string: urlString),
              let host = components.host else {
            return nil
        }
        let scheme = components.scheme ?? "https"
        return URL(string: "\(scheme)://\(host)/favicon.ico")
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.15))

            if let iconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    case .failure:
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(.secondary)
                    default:
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct EditFeedFolderView: View {
    let folder: FeedFolder
    @ObservedObject var feedsViewModel: FeedsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var folderName: String

    init(folder: FeedFolder, feedsViewModel: FeedsViewModel) {
        self.folder = folder
        self.feedsViewModel = feedsViewModel
        _folderName = State(initialValue: folder.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre de la carpeta", text: $folderName)
                        #if os(iOS)
                        .textContentType(.none)
                        #endif
                } header: {
                    Text("Nombre")
                } footer: {
                    Text("Personaliza el nombre de la carpeta.")
                }
            }
            .navigationTitle("Editar carpeta")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = folder
        updated.name = trimmed
        feedsViewModel.updateFeedFolder(updated)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        FeedsListView(
            feedsViewModel: FeedsViewModel(),
            newsViewModel: NewsViewModel(),
            smartFoldersViewModel: SmartFoldersViewModel(),
            smartFeedsViewModel: SmartFeedsViewModel()
        )
    }
}
