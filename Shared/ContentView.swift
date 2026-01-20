//
//  ContentView.swift
//  RSS RAIder
//

import SwiftUI

struct ContentView: View {
    @StateObject private var feedsViewModel = FeedsViewModel()
    @StateObject private var newsViewModel = NewsViewModel()
    @StateObject private var smartFoldersViewModel = SmartFoldersViewModel()
    @StateObject private var smartFeedsViewModel = SmartFeedsViewModel()
    @State private var didInitialRefresh = false

    var body: some View {
        Group {
        #if os(iOS)
        NavigationMenuSheet(
            feedsViewModel: feedsViewModel,
            smartFoldersViewModel: smartFoldersViewModel,
            smartFeedsViewModel: smartFeedsViewModel,
            newsViewModel: newsViewModel,
            showsCloseButton: false
        )
        #elseif os(macOS)
        NavigationSplitView {
            SidebarView(
                feedsViewModel: feedsViewModel,
                smartFoldersViewModel: smartFoldersViewModel,
                smartFeedsViewModel: smartFeedsViewModel,
                newsViewModel: newsViewModel
            )
        } detail: {
            NavigationStack {
                FeedsListView(
                    feedsViewModel: feedsViewModel,
                    newsViewModel: newsViewModel,
                    smartFoldersViewModel: smartFoldersViewModel,
                    smartFeedsViewModel: smartFeedsViewModel
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    #if os(macOS)
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                    #endif
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        #endif
        }
        .task {
            guard !didInitialRefresh else { return }
            didInitialRefresh = true
            await refreshOnLaunch()
        }
    }

    private func refreshOnLaunch() async {
        guard newsViewModel.newsItems.isEmpty else { return }

        let newsItems = await feedsViewModel.fetchAllFeeds()
        guard !newsItems.isEmpty else { return }

        await newsViewModel.processNewsItems(
            newsItems,
            smartFolders: smartFoldersViewModel.smartFolders,
            feeds: feedsViewModel.feeds
        )
        smartFoldersViewModel.updateMatchCounts(newsItems: newsViewModel.newsItems)
    }
}

#Preview {
    ContentView()
}
