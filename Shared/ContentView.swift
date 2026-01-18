//
//  ContentView.swift
//  RSSFilter
//

import SwiftUI

struct ContentView: View {
    @StateObject private var feedsViewModel = FeedsViewModel()
    @StateObject private var newsViewModel = NewsViewModel()
    @StateObject private var smartFoldersViewModel = SmartFoldersViewModel()
    @State private var selectedTab = 0

    var body: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            NavigationStack {
                NewsListView(
                    newsViewModel: newsViewModel,
                    feedsViewModel: feedsViewModel,
                    smartFoldersViewModel: smartFoldersViewModel
                )
            }
            .tabItem {
                Label("Noticias", systemImage: "newspaper")
            }
            .tag(0)

            NavigationStack {
                FeedsListView(
                    feedsViewModel: feedsViewModel,
                    newsViewModel: newsViewModel
                )
            }
            .tabItem {
                Label("Feeds", systemImage: "antenna.radiowaves.left.and.right")
            }
            .tag(1)

            NavigationStack {
                SmartFoldersListView(
                    smartFoldersViewModel: smartFoldersViewModel,
                    newsViewModel: newsViewModel
                )
            }
            .tabItem {
                Label("Carpetas", systemImage: "folder")
            }
            .tag(2)

            SettingsView(
                newsViewModel: newsViewModel,
                smartFoldersViewModel: smartFoldersViewModel,
                feedsViewModel: feedsViewModel
            )
            .tabItem {
                Label("Ajustes", systemImage: "gear")
            }
            .tag(3)
        }
        #elseif os(macOS)
        NavigationSplitView {
            SidebarView(
                feedsViewModel: feedsViewModel,
                smartFoldersViewModel: smartFoldersViewModel,
                newsViewModel: newsViewModel
            )
        } detail: {
            NewsListView(
                newsViewModel: newsViewModel,
                feedsViewModel: feedsViewModel,
                smartFoldersViewModel: smartFoldersViewModel
            )
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
}

#Preview {
    ContentView()
}
