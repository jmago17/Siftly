//
//  TextReaderView.swift
//  RSS RAIder
//

import SwiftUI

struct TextReaderView: View {
    let url: String
    let title: String
    let newsItem: NewsItem?

    @Environment(\.dismiss) private var dismiss

    @State private var articleContent: ExtractedArticleText?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var fontSize: CGFloat = 18

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Extrayendo texto...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") {
                            Task {
                                await loadArticle()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let content = articleContent {
                    // Article text
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(content.title)
                                .font(.title)
                                .fontWeight(.bold)

                            Text(content.body)
                                .font(.system(size: fontSize))
                                .lineSpacing(8)
                                .textSelection(.enabled)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Leer Artículo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach([14, 16, 18, 20, 24, 28], id: \.self) { size in
                            Button {
                                fontSize = CGFloat(size)
                            } label: {
                                HStack {
                                    Text("\(size) pt")
                                    if fontSize == CGFloat(size) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "textformat.size")
                    }
                }
            }
            .task {
                await loadArticle()
            }
            #if os(iOS)
            .simultaneousGesture(
                DragGesture(minimumDistance: 60)
                    .onEnded { value in
                        if value.translation.width < -120 {
                            dismiss()
                        }
                    }
            )
            #endif
        }
    }

    private func loadArticle() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let articleURL = URL(string: url) else {
                throw ExtractionError.invalidURL
            }

            let feedItem = FeedItem(
                title: newsItem?.title ?? title,
                descriptionHTML: newsItem?.rawSummary ?? newsItem?.summary,
                contentHTML: newsItem?.rawContent,
                link: articleURL
            )

            let extracted = await ArticleTextExtractor.shared.extract(from: feedItem)
            articleContent = extracted
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    TextReaderView(
        url: "https://example.com/article",
        title: "Example Article",
        newsItem: nil
    )
}
