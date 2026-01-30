//
//  ArticleReaderView.swift
//  RSS RAIder
//

import SwiftUI
import NaturalLanguage
#if os(iOS)
import UIKit
import WebKit
#elseif os(macOS)
import AppKit
import WebKit
#endif

struct ArticleReaderView: View {
    let url: String
    let title: String
    let newsItem: NewsItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isLoading = true
    @State private var isSummarizing = false
    @State private var summary: String?
    @State private var errorMessage: String?
    @State private var showingTextReader = false
    @State private var articleContent: ArticleContent?
    @State private var loadErrorMessage: String?
    @State private var showingAISearch = false
    @State private var aiQuestion = ""
    @State private var aiAnswer: String?
    @State private var isAISearching = false

    // Initialize with NewsItem (legacy)
    init(newsItem: NewsItem) {
        self.newsItem = newsItem
        self.url = newsItem.link
        self.title = newsItem.title
    }

    // Initialize with URL and title (for source selection)
    init(url: String, title: String) {
        self.url = url
        self.title = title
        self.newsItem = nil
    }

    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ZStack {
                    if isLoading {
                        ProgressView("Cargando articulo...")
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(10)
                    } else if let loadErrorMessage = loadErrorMessage {
                        ContentUnavailableView {
                            Label("Error", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(loadErrorMessage)
                        } actions: {
                            Button("Reintentar") {
                                Task {
                                    await loadArticleContent()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if let headerImageURL {
                                    GeometryReader { proxy in
                                        CachedAsyncImage(
                                            urlString: headerImageURL,
                                            width: proxy.size.width,
                                            height: 200,
                                            cornerRadius: 12
                                        )
                                    }
                                    .frame(height: 200)
                                }

                                // Channel/Feed name at top
                                if let feedName = newsItem?.feedName, !feedName.isEmpty {
                                    Text(feedName.uppercased())
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.accentColor)
                                        .tracking(0.5)
                                }

                                Text(titleText)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                HStack(alignment: .firstTextBaseline) {
                                    Text(authorDisplayText)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(publishedDisplayText)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                aiSummaryBox

                                if !articleBodyText.isEmpty {
                                    Text(articleBodyText)
                                        .font(.body)
                                        .lineSpacing(6)
                                        .textSelection(.enabled)
                                } else {
                                    Text("Texto no disponible.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                // Bottom padding for floating toolbar
                                Color.clear
                                    .frame(height: 80)
                            }
                            .padding()
                        }
                    }
                }

                // Bottom toolbar (floating)
                #if os(iOS)
                HStack(spacing: 0) {
                    Button {
                        showingTextReader = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "book.pages")
                                .font(.title3)
                            Text("Leer")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button {
                        openInSafari()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "safari")
                                .font(.title3)
                            Text("Safari")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button {
                        shareArticle()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                            Text("Compartir")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button {
                        showingAISearch = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.title3)
                            Text("AI Search")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                #endif
            }
            .navigationTitle(titleText)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }

                #if os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button {
                            openInSafari()
                        } label: {
                            Label("Abrir en Safari", systemImage: "safari")
                        }

                        Button {
                            showingAISearch = true
                        } label: {
                            Label("AI Search", systemImage: "magnifyingglass.circle")
                        }
                    }
                }
                #endif
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showingTextReader) {
                TextReaderView(url: url, title: title, newsItem: newsItem)
            }
            .sheet(isPresented: $showingAISearch) {
                AISearchSheet(
                    question: $aiQuestion,
                    answer: $aiAnswer,
                    isSearching: $isAISearching,
                    onSearch: performAISearch
                )
            }
            .task {
                await loadArticleContent()
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

    private func loadAISummaryIfNeeded() {
        #if os(iOS)
        guard #available(iOS 18.0, *) else {
            return
        }
        #elseif os(macOS)
        guard #available(macOS 15.0, *) else {
            return
        }
        #endif

        guard summary == nil, !isSummarizing else { return }
        isSummarizing = true

        Task {
            do {
                let summaryText = try await generateSummary()
                await MainActor.run {
                    summary = summaryText
                    isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    summary = "No se pudo generar un resumen."
                    isSummarizing = false
                }
            }
        }
    }

    private func loadArticleContent() async {
        isLoading = true
        loadErrorMessage = nil

        do {
            if let newsItem = newsItem, let articleURL = URL(string: newsItem.link) {
                let feedItem = FeedItem(
                    title: newsItem.title,
                    descriptionHTML: newsItem.rawSummary ?? newsItem.summary,
                    contentHTML: newsItem.rawContent,
                    link: articleURL
                )
                let extracted = await ArticleTextExtractor.shared.extract(from: feedItem)
                if !extracted.body.isEmpty {
                    await MainActor.run {
                        articleContent = ArticleContent(
                            title: extracted.title,
                            text: extracted.body,
                            url: articleURL.absoluteString,
                            imageURL: newsItem.imageURL,
                            author: newsItem.author
                        )
                        isLoading = false
                        loadAISummaryIfNeeded()
                    }
                    return
                }
            }

            var content = try await HTMLTextExtractor.shared.extractText(from: url)
            // Preserve image URL from newsItem if extractor didn't find one
            if content.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
               let newsItemImage = newsItem?.imageURL,
               !newsItemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = ArticleContent(
                    title: content.title,
                    text: content.text,
                    url: content.url,
                    imageURL: newsItemImage,
                    author: content.author ?? newsItem?.author
                )
            }
            await MainActor.run {
                articleContent = content
                isLoading = false
                loadAISummaryIfNeeded()
            }
        } catch {
            await MainActor.run {
                loadErrorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func generateSummary() async throws -> String {
        let sourceText = await summarySourceText()
        let cleanedSource = prepareSummarySource(sourceText)
        let limits = summaryLimits(for: cleanedSource)
        let summaryText = extractiveSummary(from: cleanedSource, maxSentences: limits.sentences, maxCharacters: limits.characters)

        if !summaryText.isEmpty {
            return summaryText
        }

        let fallback = fallbackSummaryText()
        return fallback.isEmpty ? "Resumen no disponible." : fallback
    }

    private func summarySourceText() async -> String {
        if let cached = articleContent?.text, !cached.isEmpty {
            return cached
        }

        if let cleanBody = newsItem?.cleanBody, !cleanBody.isEmpty {
            return cleanBody
        }

        if let cleaned = cleanedHTMLText(newsItem?.rawContent), !cleaned.isEmpty {
            return cleaned
        }

        if let cleaned = cleanedHTMLText(newsItem?.rawSummary), !cleaned.isEmpty {
            return cleaned
        }

        do {
            let content = try await HTMLTextExtractor.shared.extractText(from: url)
            return content.text
        } catch {
            return newsItem?.summary ?? ""
        }
    }

    private func cleanedHTMLText(_ html: String?) -> String? {
        guard let html, !html.isEmpty else { return nil }
        // Use the comprehensive text cleaner for better summarization
        let cleaned = TextCleaner.cleanForSummarization(html)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func summaryLimits(for text: String) -> (sentences: Int, characters: Int) {
        let length = text.count
        if length > 8000 {
            return (10, 2200)
        }
        if length > 5000 {
            return (8, 2000)
        }
        if length > 3000 {
            return (6, 1700)
        }
        return (5, 1400)
    }

    private func fallbackSummaryText() -> String {
        if let summary = newsItem?.summary, !summary.isEmpty {
            return summary
        }
        return ""
    }

    private func extractiveSummary(from text: String, maxSentences: Int, maxCharacters: Int) -> String {
        let cleaned = normalizeWhitespace(text)
        guard cleaned.count > 60 else { return cleaned }

        let sentences = splitIntoSentences(cleaned)
        guard sentences.count > 1 else { return cleaned }

        let stopwords = Set([
            "de", "la", "el", "los", "las", "un", "una", "unos", "unas", "del", "al", "y", "e", "o", "u",
            "para", "por", "con", "sin", "en", "a", "que", "se", "es", "su", "sus", "como", "mas", "pero",
            "the", "and", "or", "of", "to", "in", "on", "for", "is", "are", "was", "were", "be"
        ])

        let candidateSentences = sentences.filter { isSummarizableSentence($0) }
        let scoringSentences = candidateSentences.count >= 2 ? candidateSentences : sentences

        var wordFrequency: [String: Int] = [:]
        for sentence in scoringSentences {
            for word in tokenize(sentence, stopwords: stopwords) {
                wordFrequency[word, default: 0] += 1
            }
        }

        let scoredSentences = scoringSentences.enumerated().map { index, sentence -> (Int, Double, String) in
            let words = tokenize(sentence, stopwords: stopwords)
            let score = words.reduce(0.0) { $0 + Double(wordFrequency[$1, default: 0]) }
            let normalizedScore = score / max(Double(words.count), 1.0)
            return (index, normalizedScore, sentence)
        }

        let selected = scoredSentences
            .sorted { $0.1 > $1.1 }
            .prefix(maxSentences)
            .sorted { $0.0 < $1.0 }
            .map { $0.2 }

        var summary = selected.joined(separator: " ")
        if summary.count > maxCharacters {
            summary = String(summary.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return summary
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let pattern = "[^.!?]+[.!?]?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [text]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        let sentences = matches.map { match in
            nsText.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return sentences.filter { !$0.isEmpty }
    }

    private func tokenize(_ text: String, stopwords: Set<String>) -> [String] {
        let normalized = text.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        let parts = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return parts.filter { $0.count > 2 && !stopwords.contains($0) }
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prepareSummarySource(_ text: String) -> String {
        // First apply comprehensive cleaning
        let preCleaned = TextCleaner.cleanForSummarization(text)
        let cleaned = normalizeWhitespace(preCleaned)
        guard !cleaned.isEmpty else { return cleaned }

        let sentences = splitIntoSentences(cleaned)
        let filtered = sentences.filter { isSummarizableSentence($0) }

        if filtered.count >= 2 {
            return filtered.joined(separator: " ")
        }

        return cleaned
    }

    private func isSummarizableSentence(_ sentence: String) -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 30 else { return false }
        if looksStructured(trimmed) {
            return false
        }
        if looksLikeSocialShare(trimmed) {
            return false
        }
        return true
    }

    private func looksLikeSocialShare(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()

        // Social network names
        let socialNetworks = ["facebook", "twitter", "linkedin", "whatsapp", "telegram",
                              "pinterest", "reddit", "instagram", "tiktok", "youtube"]

        // Check if sentence is dominated by social network mentions
        var socialCount = 0
        for network in socialNetworks {
            if lower.contains(network) {
                socialCount += 1
            }
        }

        // If multiple social networks mentioned, likely a share bar
        if socialCount >= 2 {
            return true
        }

        // Check for share action patterns
        let sharePatterns = [
            "share on", "share this", "share via", "compartir en", "compartir este",
            "tweet this", "pin it", "me gusta", "follow us", "siguenos",
            "subscribe to", "suscribete", "newsletter"
        ]

        for pattern in sharePatterns {
            if lower.contains(pattern) {
                return true
            }
        }

        return false
    }

    private func looksStructured(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        if lower.contains("{") || lower.contains("}") || lower.contains("\"@") {
            return true
        }
        if lower.contains("schema.org") || lower.contains("application/ld+json") {
            return true
        }
        if lower.contains("</") || lower.contains("/>") {
            return true
        }

        let letters = sentence.filter { $0.isLetter }
        let symbols = sentence.filter { "{}[]<>:\"".contains($0) }
        if symbols.count >= 3 && letters.count < 25 {
            return true
        }

        if lower.range(of: "\"[a-z0-9_\\-]+\"\\s*:", options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private var titleText: String {
        if let newsItemTitle = newsItem?.title, !newsItemTitle.isEmpty {
            return newsItemTitle
        }
        if let extractedTitle = articleContent?.title, !extractedTitle.isEmpty {
            return extractedTitle
        }
        return title
    }

    private var authorDisplayText: String {
        if let author = articleContent?.author, !author.isEmpty {
            return author
        }
        if let feedName = newsItem?.feedName, !feedName.isEmpty {
            return feedName
        }
        return "Autor desconocido"
    }

    private var publishedDisplayText: String {
        if let pubDate = newsItem?.pubDate {
            return pubDate.formatted(date: .abbreviated, time: .shortened)
        }
        return "Fecha desconocida"
    }

    private var articleBodyText: String {
        if let text = articleContent?.text, !text.isEmpty {
            return text
        }
        if let cleanBody = newsItem?.cleanBody, !cleanBody.isEmpty {
            return cleanBody
        }
        return ""
    }

    private var headerImageURL: String? {
        if let imageURL = articleContent?.imageURL,
           !imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return imageURL
        }
        if let imageURL = newsItem?.imageURL,
           !imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return imageURL
        }
        return nil
    }

    private var aiSummaryBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Summary", systemImage: "sparkles")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if isSummarizing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Generando resumen...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            } else if let summary = summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .textSelection(.enabled)
            } else {
                Text("Resumen no disponible.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .cornerRadius(12)
    }

    private func performAISearch() {
        let question = aiQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        let sourceText = articleContent?.text
            ?? newsItem?.cleanBody
            ?? newsItem?.summary
            ?? ""

        guard !sourceText.isEmpty else {
            aiAnswer = "No hay texto disponible para analizar."
            return
        }

        isAISearching = true
        Task {
            let answer: String
            if #available(iOS 18.0, macOS 15.0, *) {
                do {
                    let service = AppleIntelligenceService()
                    let response = try await service.answerQuestion(question: question, context: sourceText)
                    answer = response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? extractAnswer(from: sourceText, question: question)
                        : response
                } catch {
                    answer = extractAnswer(from: sourceText, question: question)
                }
            } else {
                answer = extractAnswer(from: sourceText, question: question)
            }

            await MainActor.run {
                aiAnswer = clampAISearchAnswer(answer)
                isAISearching = false
            }
        }
    }

    private func extractAnswer(from text: String, question: String) -> String {
        let questionTokens = tokenize(question)
        guard !questionTokens.isEmpty else {
            return "Introduce una pregunta mas concreta."
        }

        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text

        var scored: [(String, Int)] = []
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard sentence.count > 20 else { return true }
            let sentenceTokens = tokenize(sentence)
            let overlap = questionTokens.intersection(sentenceTokens).count
            if overlap > 0 {
                scored.append((sentence, overlap))
            }
            return scored.count < 80
        }

        guard !scored.isEmpty else {
            return "No se encontraron coincidencias. Prueba con otras palabras."
        }

        let topSentences = scored.sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0.0 }

        return topSentences.joined(separator: " ")
    }

    private func clampAISearchAnswer(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 0 else { return trimmed }

        let sentences = splitIntoSentences(trimmed)
        if sentences.count > 3 {
            let short = sentences.prefix(3).joined(separator: " ")
            return short.count > 700 ? String(short.prefix(700)).trimmingCharacters(in: .whitespacesAndNewlines) + "…" : short
        }

        if trimmed.count > 700 {
            return String(trimmed.prefix(700)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }

        return trimmed
    }

    private func tokenize(_ text: String) -> Set<String> {
        let lowered = text.lowercased()
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = lowered
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: lowered.startIndex..<lowered.endIndex) { range, _ in
            let token = String(lowered[range])
            if token.count >= 3 {
                tokens.append(token)
            }
            return true
        }
        return Set(tokens)
    }

    private func shareArticle() {
        #if os(iOS)
        guard let urlObj = URL(string: url) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [title, urlObj],
            applicationActivities: nil
        )

        guard let presenter = topViewController() else { return }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
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

    private func openInSafari() {
        guard let urlObj = URL(string: url) else { return }

        #if os(iOS)
        UIApplication.shared.open(urlObj)
        #elseif os(macOS)
        NSWorkspace.shared.open(urlObj)
        #endif
    }
}

// MARK: - WebView

struct WebView: View {
    let url: URL
    @Binding var isLoading: Bool

    var body: some View {
        #if os(iOS)
        WebViewRepresentable(url: url, isLoading: $isLoading)
        #elseif os(macOS)
        WebViewRepresentable(url: url, isLoading: $isLoading)
        #endif
    }
}

#if os(iOS)
struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Don't reload on every update - only load in makeUIView
        // This prevents constant reloading
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
#elseif os(macOS)
struct WebViewRepresentable: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Don't reload on every update - only load in makeNSView
        // This prevents constant reloading
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
#endif

struct AISearchSheet: View {
    @Binding var question: String
    @Binding var answer: String?
    @Binding var isSearching: Bool
    let onSearch: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Pregunta al articulo")
                    .font(.headline)

                TextField("Escribe tu pregunta", text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    onSearch()
                } label: {
                    if isSearching {
                        ProgressView()
                    } else {
                        Label("Buscar con AI", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)

                if let answer = answer {
                    ScrollView {
                        Text(answer)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 260)
                    .padding()
                    #if os(iOS)
                    .background(Color(uiColor: .secondarySystemBackground))
                    #else
                    .background(Color(nsColor: .controlBackgroundColor))
                    #endif
                    .cornerRadius(10)
                } else {
                    Text("Haz una pregunta para buscar respuestas en el texto.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("AI Search")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ArticleReaderView(
        newsItem: NewsItem(
            id: "test",
            title: "Ejemplo de Noticia",
            summary: "Este es un resumen de ejemplo de una noticia interesante.",
            link: "https://example.com",
            pubDate: Date(),
            feedID: UUID(),
            feedName: "Feed de Ejemplo",
            imageURL: nil,
            author: "Autor Ejemplo",
            rawSummary: nil,
            rawContent: nil,
            cleanTitle: nil,
            cleanBody: nil,
            qualityScore: nil,
            duplicateGroupID: nil,
            smartFolderIDs: []
        )
    )
}
