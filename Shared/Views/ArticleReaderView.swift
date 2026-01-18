//
//  ArticleReaderView.swift
//  RSSFilter
//

import SwiftUI
#if os(iOS)
import UIKit
import WebKit
#elseif os(macOS)
import AppKit
import WebKit
#endif

struct ArticleReaderView: View {
    let newsItem: NewsItem
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var isSummarizing = false
    @State private var summary: String?
    @State private var showingSummary = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                WebView(url: URL(string: newsItem.link)!, isLoading: $isLoading)

                if isLoading {
                    ProgressView("Cargando artículo...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }

                if showingSummary, let summary = summary {
                    VStack {
                        Spacer()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                Text("Resumen con Apple Intelligence")
                                    .font(.headline)

                                Spacer()

                                Button {
                                    withAnimation {
                                        showingSummary = false
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }

                            ScrollView {
                                Text(summary)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 300)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .padding()
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle(newsItem.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }

                #if os(iOS)
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            summarizeArticle()
                        } label: {
                            Label("Resumir con AI", systemImage: "sparkles")
                        }
                        .disabled(isSummarizing)

                        Button {
                            shareArticle()
                        } label: {
                            Label("Compartir", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            openInSafari()
                        } label: {
                            Label("Abrir en Safari", systemImage: "safari")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        summarizeArticle()
                    } label: {
                        Label("Resumir", systemImage: "sparkles")
                    }
                    .disabled(isSummarizing)
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
        }
    }

    private func summarizeArticle() {
        #if os(iOS)
        guard #available(iOS 18.0, *) else {
            errorMessage = "Resúmenes con Apple Intelligence requiere iOS 18 o superior"
            return
        }
        #elseif os(macOS)
        guard #available(macOS 15.0, *) else {
            errorMessage = "Resúmenes con Apple Intelligence requiere macOS 15 o superior"
            return
        }
        #endif

        isSummarizing = true

        Task {
            do {
                let summaryText = try await generateSummary(for: newsItem)
                await MainActor.run {
                    self.summary = summaryText
                    withAnimation {
                        self.showingSummary = true
                    }
                    self.isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error al generar resumen: \(error.localizedDescription)"
                    self.isSummarizing = false
                }
            }
        }
    }

    private func generateSummary(for newsItem: NewsItem) async throws -> String {
        // Use simple text-based summarization
        // In a real app with Apple Intelligence APIs, you would use the Writing Tools API
        _ = """
        Título: \(newsItem.title)

        Resumen: \(newsItem.summary)

        Fuente: \(newsItem.feedName)
        """

        // Simulate AI summarization (in production, use Apple Intelligence APIs)
        return """
        📰 \(newsItem.title)

        Este artículo trata sobre \(newsItem.summary.prefix(200))...

        🔍 Puntos clave:
        • Fuente: \(newsItem.feedName)
        • Publicado: \(newsItem.pubDate?.formatted(date: .abbreviated, time: .shortened) ?? "Fecha desconocida")

        💡 El contenido principal se centra en los temas mencionados en el resumen del artículo.
        """
    }

    private func shareArticle() {
        #if os(iOS)
        guard let url = URL(string: newsItem.link) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [newsItem.title, url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }

    private func openInSafari() {
        guard let url = URL(string: newsItem.link) else { return }

        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
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
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
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
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
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
            qualityScore: nil,
            duplicateGroupID: nil,
            smartFolderIDs: []
        )
    )
}
