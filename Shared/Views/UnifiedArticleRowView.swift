//
//  UnifiedArticleRowView.swift
//  RSS RAIder
//
//  Unified article row component used across all list views

import SwiftUI

struct UnifiedArticleRowView: View {
    let newsItem: DeduplicatedNewsItem
    @ObservedObject var newsViewModel: NewsViewModel
    let feedSettings: [UUID: RSSFeed]
    let onTap: () -> Void
    let onSourceSelect: (() -> Void)?

    init(
        newsItem: DeduplicatedNewsItem,
        newsViewModel: NewsViewModel,
        feedSettings: [UUID: RSSFeed],
        onTap: @escaping () -> Void,
        onSourceSelect: (() -> Void)? = nil
    ) {
        self.newsItem = newsItem
        self.newsViewModel = newsViewModel
        self.feedSettings = feedSettings
        self.onTap = onTap
        self.onSourceSelect = onSourceSelect
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: Feed info on left, time + score on right
                HStack(alignment: .center, spacing: 8) {
                    // Feed logo placeholder (first letter) + feed name
                    HStack(spacing: 6) {
                        feedLogoView

                        if newsItem.hasDuplicates {
                            Button {
                                onSourceSelect?()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("\(newsItem.sources.count) fuentes")
                                        .font(.caption)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(newsItem.primarySource.feedName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Time + Score
                    HStack(spacing: 8) {
                        if let pubDate = newsItem.pubDate {
                            Text(relativeTimeString(from: pubDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let score = newsItem.qualityScore {
                            ScoreBadge(score: score.overallScore)
                        }
                    }
                }

                // Main content: Title + Summary on left, Image on right
                HStack(alignment: .top, spacing: 12) {
                    // Title + Summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text(newsItem.title)
                            .font(.subheadline)
                            .fontWeight(newsItem.isRead ? .regular : .semibold)
                            .foregroundColor(newsItem.isRead ? .secondary : .primary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if !newsItem.summary.isEmpty {
                            Text(cleanSummary(newsItem.summary))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Thumbnail image on the right
                    if let imageURL = newsItem.imageURL {
                        CachedAsyncImage(urlString: imageURL, width: 80, height: 80)
                    }
                }

                // Warning badges (only if present)
                if hasWarningBadges {
                    HStack(spacing: 6) {
                        if newsItem.qualityScore?.isClickbait == true {
                            WarningBadge(text: "Clickbait", color: .orange)
                        }
                        if newsItem.qualityScore?.isSpam == true {
                            WarningBadge(text: "Spam", color: .red)
                        }
                        if newsItem.qualityScore?.isAdvertisement == true {
                            WarningBadge(text: "Anuncio", color: .purple)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var feedLogoView: some View {
        let feedName = newsItem.primarySource.feedName
        let feedID = newsItem.primarySource.feedID
        let logoURL = feedSettings[feedID]?.logoURL

        if let logoURL = logoURL {
            CachedAsyncImage(urlString: logoURL, width: 22, height: 22, cornerRadius: 11)
        } else {
            let initial = String(feedName.prefix(1)).uppercased()
            let color = colorForFeed(feedName)

            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                Text(initial)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(width: 22, height: 22)
        }
    }

    // MARK: - Helpers

    private var hasWarningBadges: Bool {
        newsItem.qualityScore?.isClickbait == true ||
        newsItem.qualityScore?.isSpam == true ||
        newsItem.qualityScore?.isAdvertisement == true
    }

    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Ahora"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM"
            return formatter.string(from: date)
        }
    }

    private func cleanSummary(_ text: String) -> String {
        // Remove excessive whitespace and newlines
        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    private func colorForFeed(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(scoreColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }

    private var scoreColor: Color {
        switch score {
        case 80...100:
            return .green
        case 50...79:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Warning Badge

struct WarningBadge: View {
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

// MARK: - Unified Row with Swipe Actions

struct UnifiedArticleRow: View {
    let newsItem: DeduplicatedNewsItem
    @ObservedObject var newsViewModel: NewsViewModel
    let feedSettings: [UUID: RSSFeed]
    @State private var selectedSource: NewsItemSource?
    @State private var showingSourceSelector = false

    var body: some View {
        UnifiedArticleRowView(
            newsItem: newsItem,
            newsViewModel: newsViewModel,
            feedSettings: feedSettings,
            onTap: {
                selectedSource = newsItem.primarySource
            },
            onSourceSelect: newsItem.hasDuplicates ? {
                showingSourceSelector = true
            } : nil
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleFavorite()
            } label: {
                Label(
                    newsItem.isFavorite ? "Quitar favorito" : "Favorito",
                    systemImage: newsItem.isFavorite ? "star.slash.fill" : "star.fill"
                )
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                toggleRead()
            } label: {
                Label(
                    newsItem.isRead ? "No leído" : "Leído",
                    systemImage: newsItem.isRead ? "envelope.open.fill" : "envelope.fill"
                )
            }
            .tint(newsItem.isRead ? .orange : .blue)
        }
        .sheet(item: $selectedSource) { source in
            Group {
                if shouldOpenInSafariReader(for: source),
                   let url = URL(string: source.link) {
                    SafariReaderView(url: url)
                } else {
                    ArticleReaderView(url: source.link, title: newsItem.title)
                }
            }
            .onDisappear {
                // Mark as read when reader closes
                source.markAsRead(true)
                newsViewModel.objectWillChange.send()
            }
            #if os(iOS)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
            #endif
        }
        .confirmationDialog("Seleccionar fuente", isPresented: $showingSourceSelector, titleVisibility: .visible) {
            ForEach(newsItem.sources) { source in
                Button(source.feedName) {
                    selectedSource = source
                }
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Elige la fuente que quieres leer")
        }
    }

    private func toggleRead() {
        let newReadStatus = !newsItem.isRead
        for source in newsItem.sources {
            newsViewModel.markAsRead(source.id, isRead: newReadStatus, notify: false)
        }
        newsViewModel.objectWillChange.send()
    }

    private func toggleFavorite() {
        let newFavoriteStatus = !newsItem.isFavorite
        for source in newsItem.sources {
            newsViewModel.markAsFavorite(source.id, isFavorite: newFavoriteStatus, notify: false)
        }
        newsViewModel.objectWillChange.send()
    }

    private func shouldOpenInSafariReader(for source: NewsItemSource) -> Bool {
        #if os(iOS)
        return feedSettings[source.feedID]?.openInSafariReader ?? false
        #else
        return false
        #endif
    }
}

// MARK: - NewsItem Row (for SmartFolders)

struct UnifiedNewsItemRow: View {
    let newsItem: NewsItem
    @ObservedObject var newsViewModel: NewsViewModel
    let feedSettings: [UUID: RSSFeed]
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: Feed info on left, time + score on right
                HStack(alignment: .center, spacing: 8) {
                    // Feed logo placeholder (first letter) + feed name
                    HStack(spacing: 6) {
                        feedLogoView

                        Text(newsItem.feedName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Time + Score
                    HStack(spacing: 8) {
                        if let pubDate = newsItem.pubDate {
                            Text(relativeTimeString(from: pubDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let score = newsItem.qualityScore {
                            ScoreBadge(score: score.overallScore)
                        }
                    }
                }

                // Main content: Title + Summary on left, Image on right
                HStack(alignment: .top, spacing: 12) {
                    // Title + Summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text(newsItem.title)
                            .font(.subheadline)
                            .fontWeight(newsItem.isRead ? .regular : .semibold)
                            .foregroundColor(newsItem.isRead ? .secondary : .primary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if !newsItem.summary.isEmpty {
                            Text(cleanSummary(newsItem.summary))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Thumbnail image on the right
                    if let imageURL = newsItem.imageURL {
                        CachedAsyncImage(urlString: imageURL, width: 80, height: 80)
                    }
                }

                // Warning badges (only if present)
                if hasWarningBadges {
                    HStack(spacing: 6) {
                        if newsItem.qualityScore?.isClickbait == true {
                            WarningBadge(text: "Clickbait", color: .orange)
                        }
                        if newsItem.qualityScore?.isSpam == true {
                            WarningBadge(text: "Spam", color: .red)
                        }
                        if newsItem.qualityScore?.isAdvertisement == true {
                            WarningBadge(text: "Anuncio", color: .purple)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleFavorite()
            } label: {
                Label(
                    newsItem.isFavorite ? "Quitar favorito" : "Favorito",
                    systemImage: newsItem.isFavorite ? "star.slash.fill" : "star.fill"
                )
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                toggleRead()
            } label: {
                Label(
                    newsItem.isRead ? "No leído" : "Leído",
                    systemImage: newsItem.isRead ? "envelope.open.fill" : "envelope.fill"
                )
            }
            .tint(newsItem.isRead ? .orange : .blue)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var feedLogoView: some View {
        let logoURL = feedSettings[newsItem.feedID]?.logoURL

        if let logoURL = logoURL {
            CachedAsyncImage(urlString: logoURL, width: 22, height: 22, cornerRadius: 11)
        } else {
            let initial = String(newsItem.feedName.prefix(1)).uppercased()
            let color = colorForFeed(newsItem.feedName)

            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                Text(initial)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(width: 22, height: 22)
        }
    }

    // MARK: - Helpers

    private var hasWarningBadges: Bool {
        newsItem.qualityScore?.isClickbait == true ||
        newsItem.qualityScore?.isSpam == true ||
        newsItem.qualityScore?.isAdvertisement == true
    }

    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Ahora"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM"
            return formatter.string(from: date)
        }
    }

    private func cleanSummary(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    private func colorForFeed(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    private func toggleRead() {
        newsViewModel.markAsRead(newsItem.id, isRead: !newsItem.isRead)
    }

    private func toggleFavorite() {
        newsViewModel.markAsFavorite(newsItem.id, isFavorite: !newsItem.isFavorite)
    }
}
