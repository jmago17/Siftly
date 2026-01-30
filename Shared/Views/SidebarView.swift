//
//  SidebarView.swift
//  RSS RAIder
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var smartTagsViewModel: SmartTagsViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @State private var showingAddFeed = false
    @State private var showingAddFeedFolder = false
    @State private var showingAddSmartFolder = false
    @State private var showingSettings = false

    var body: some View {
        List {
            // RSS Feeds Section
            Section {
                ForEach(feedFolderSections) { section in
                    DisclosureGroup(isExpanded: .constant(true)) {
                        if section.feeds.isEmpty {
                            Text("Sin feeds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(section.feeds) { feed in
                                FeedRowView(feed: feed)
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
                }

                Button {
                    showingAddFeed = true
                } label: {
                    Label("Añadir Feed", systemImage: "plus.circle")
                }

                Button {
                    showingAddFeedFolder = true
                } label: {
                    Label("Nueva carpeta", systemImage: "folder.badge.plus")
                }
            } header: {
                HStack {
                    Text("RSS Feeds")
                    Spacer()
                    if feedsViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }

            // Smart Folders Section
            Section {
                ForEach(smartFoldersViewModel.smartFolders.filter { $0.isEnabled }) { folder in
                    NavigationLink {
                        Text("Smart folder: \(folder.name)")
                    } label: {
                        SmartFolderRowView(folder: folder)
                    }
                }

                Button {
                    showingAddSmartFolder = true
                } label: {
                    Label("Nueva Carpeta Inteligente", systemImage: "folder.badge.plus")
                }
            } header: {
                Text("Carpetas Inteligentes")
            }
        }
        .navigationTitle("RSS Filter")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        _ = await feedsViewModel.fetchAllFeeds()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(feedsViewModel.isLoading)
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingAddFeed) {
            AddFeedView(feedsViewModel: feedsViewModel)
        }
        .sheet(isPresented: $showingAddFeedFolder) {
            AddFeedFolderView(feedsViewModel: feedsViewModel)
        }
        .sheet(isPresented: $showingAddSmartFolder) {
            AddSmartFolderView(smartFoldersViewModel: smartFoldersViewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                newsViewModel: newsViewModel,
                smartFoldersViewModel: smartFoldersViewModel,
                smartFeedsViewModel: smartFeedsViewModel,
                feedsViewModel: feedsViewModel
            )
        }
    }

    private var feedFolderSections: [SidebarFeedFolderSection] {
        let groupedFeedIDs = Set(feedsViewModel.feedFolders.flatMap { $0.feedIDs })
        let ungroupedFeeds = feedsViewModel.feeds.filter { !groupedFeedIDs.contains($0.id) }

        var sections: [SidebarFeedFolderSection] = feedsViewModel.feedFolders.map { folder in
            let feeds = feedsViewModel.feeds.filter { folder.feedIDs.contains($0.id) }
            return SidebarFeedFolderSection(id: folder.id, title: folder.name, feeds: feeds)
        }

        if !ungroupedFeeds.isEmpty {
            sections.append(SidebarFeedFolderSection(id: SidebarFeedFolderSection.ungroupedID, title: "Sin carpeta", feeds: ungroupedFeeds))
        }

        return sections
    }
}

private struct SidebarFeedFolderSection: Identifiable {
    let id: UUID
    let title: String
    let feeds: [RSSFeed]

    static let ungroupedID = UUID()

    var count: Int {
        feeds.count
    }
}

struct FeedRowView: View {
    let feed: RSSFeed

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            FeedIconView(urlString: feed.url, size: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.name)
                    .font(.headline)

                if let error = feed.lastFetchError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct SmartFolderRowView: View {
    let folder: SmartFolder

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.headline)

                if folder.matchCount > 0 {
                    Text("\(folder.matchCount) artículos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if folder.matchCount > 0 {
                Text("\(folder.matchCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    NavigationStack {
        SidebarView(
            feedsViewModel: FeedsViewModel(),
            smartFoldersViewModel: SmartFoldersViewModel(),
            smartFeedsViewModel: SmartFeedsViewModel(),
            smartTagsViewModel: SmartTagsViewModel(),
            newsViewModel: NewsViewModel()
        )
    }
}
