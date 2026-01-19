//
//  FeedsListView.swift
//  RSS RAIder
//

import SwiftUI

struct FeedsListView: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @State private var showingAddFeed = false

    var body: some View {
        Group {
            if feedsViewModel.feeds.isEmpty {
                ContentUnavailableView {
                    Label("No hay feeds RSS", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Añade feeds RSS para comenzar a ver noticias")
                } actions: {
                    Button("Añadir Feed") {
                        showingAddFeed = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(feedsViewModel.feeds) { feed in
                        NavigationLink {
                            FeedNewsView(
                                feed: feed,
                                newsViewModel: newsViewModel,
                                feedsViewModel: feedsViewModel
                            )
                        } label: {
                            FeedDetailRowView(feed: feed, feedsViewModel: feedsViewModel)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            feedsViewModel.deleteFeed(id: feedsViewModel.feeds[index].id)
                        }
                    }
                }
                .refreshable {
                    _ = await feedsViewModel.fetchAllFeeds()
                }
            }
        }
        .navigationTitle("RSS Feeds")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFeed = true
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
        .overlay {
            if feedsViewModel.isLoading {
                ProgressView("Actualizando feeds...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
    }
}

struct FeedDetailRowView: View {
    let feed: RSSFeed
    @ObservedObject var feedsViewModel: FeedsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(feed.name)
                        .font(.headline)

                    Text(feed.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { feed.isEnabled },
                    set: { _ in feedsViewModel.toggleFeed(id: feed.id) }
                ))
                .labelsHidden()
            }

            if let lastUpdated = feed.lastUpdated {
                Text("Última actualización: \(lastUpdated, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let error = feed.lastFetchError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        FeedsListView(
            feedsViewModel: FeedsViewModel(),
            newsViewModel: NewsViewModel()
        )
    }
}
