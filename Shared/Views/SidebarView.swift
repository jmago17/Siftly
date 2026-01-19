//
//  SidebarView.swift
//  RSS RAIder
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @State private var showingAddFeed = false
    @State private var showingAddFolder = false
    @State private var showingSettings = false

    var body: some View {
        List {
            // All News Section
            Section("Todas las noticias") {
                NavigationLink {
                    Text("All news will be displayed here")
                } label: {
                    Label("Todas", systemImage: "newspaper")
                }
            }

            // RSS Feeds Section
            Section {
                ForEach(feedsViewModel.feeds) { feed in
                    FeedRowView(feed: feed, feedsViewModel: feedsViewModel)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        feedsViewModel.deleteFeed(id: feedsViewModel.feeds[index].id)
                    }
                }

                Button {
                    showingAddFeed = true
                } label: {
                    Label("Añadir Feed", systemImage: "plus.circle")
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
                    showingAddFolder = true
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
        .sheet(isPresented: $showingAddFolder) {
            AddSmartFolderView(smartFoldersViewModel: smartFoldersViewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(newsViewModel: newsViewModel, smartFoldersViewModel: smartFoldersViewModel, feedsViewModel: feedsViewModel)
        }
    }
}

struct FeedRowView: View {
    let feed: RSSFeed
    @ObservedObject var feedsViewModel: FeedsViewModel

    var body: some View {
        HStack {
            Image(systemName: feed.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(feed.isEnabled ? .green : .gray)
                .onTapGesture {
                    feedsViewModel.toggleFeed(id: feed.id)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.name)
                    .font(.headline)

                if let lastUpdated = feed.lastUpdated {
                    Text("Actualizado: \(lastUpdated, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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
            newsViewModel: NewsViewModel()
        )
    }
}
