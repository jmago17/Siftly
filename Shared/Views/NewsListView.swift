//
//  NewsListView.swift
//  RSSFilter
//

import SwiftUI

struct NewsListView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @State private var selectedFeedID: UUID?
    @State private var selectedSmartFolderID: UUID?
    @State private var isRefreshing = false

    var body: some View {
        Group {
            if newsViewModel.newsItems.isEmpty {
                ContentUnavailableView {
                    Label("No hay noticias", systemImage: "newspaper")
                } description: {
                    Text("Añade feeds RSS para comenzar a ver noticias")
                }
            } else {
                List {
                    ForEach(filteredNews) { item in
                        NewsRowView(newsItem: item)
                    }
                }
                .refreshable {
                    await refreshNews()
                }
            }
        }
        .navigationTitle("Noticias")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if newsViewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button {
                        Task {
                            await refreshNews()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .overlay {
            if isRefreshing {
                ProgressView("Actualizando noticias...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
    }

    private var filteredNews: [NewsItem] {
        newsViewModel.getNewsItems(
            for: selectedFeedID,
            smartFolderID: selectedSmartFolderID
        )
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
}

struct NewsRowView: View {
    let newsItem: NewsItem
    @State private var showingReader = false

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
                // Feed name
                Text(newsItem.feedName)
                    .font(.caption)
                    .foregroundColor(.blue)

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
                if newsItem.duplicateGroupID != nil {
                    Badge(text: "Duplicado", color: .gray)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingReader = true
        }
        .sheet(isPresented: $showingReader) {
            ArticleReaderView(newsItem: newsItem)
        }
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

#Preview {
    NavigationStack {
        NewsListView(
            newsViewModel: NewsViewModel(),
            feedsViewModel: FeedsViewModel(),
            smartFoldersViewModel: SmartFoldersViewModel()
        )
    }
}
