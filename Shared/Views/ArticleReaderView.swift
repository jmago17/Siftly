//
//  ArticleReaderView.swift
//  RSS RAIder
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
    let url: String
    let title: String
    let newsItem: NewsItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isLoading = true
    @State private var isSummarizing = false
    @State private var summary: String?
    @State private var showingSummary = false
    @State private var errorMessage: String?

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
            VStack(spacing: 0) {
                ZStack {
                    WebView(url: URL(string: url)!, isLoading: $isLoading)

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
                            .padding(.bottom, 60) // Make room for bottom toolbar
                        }
                        .transition(.move(edge: .bottom))
                    }
                }

                // Bottom toolbar
                #if os(iOS)
                HStack(spacing: 0) {
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

                    Divider()
                        .frame(height: 40)

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

                    Divider()
                        .frame(height: 40)

                    Button {
                        summarizeArticle()
                    } label: {
                        VStack(spacing: 4) {
                            if isSummarizing {
                                ProgressView()
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                            }
                            Text("Resumir")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isSummarizing)
                }
                .padding(.vertical, 8)
                .background(.regularMaterial)
                #endif
            }
            .navigationTitle(title)
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
                            summarizeArticle()
                        } label: {
                            Label("Resumir", systemImage: "sparkles")
                        }
                        .disabled(isSummarizing)
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
                let summaryText = try await generateSummary()
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

    private func generateSummary() async throws -> String {
        if let newsItem = newsItem {
            // Use simple text-based summarization
            // In a real app with Apple Intelligence APIs, you would use the Writing Tools API
            let summary = newsItem.summary.isEmpty ? "El artículo no tiene resumen disponible." : String(newsItem.summary.prefix(300))

            return """
            📰 \(newsItem.title)

            \(summary)

            🔍 Puntos clave:
            • Fuente: \(newsItem.feedName)
            • Publicado: \(newsItem.pubDate?.formatted(date: .abbreviated, time: .shortened) ?? "Fecha desconocida")
            \(newsItem.qualityScore != nil ? "• Puntuación: \(newsItem.qualityScore!.overallScore)/100" : "")

            💡 Este es un resumen generado automáticamente. Para más detalles, lee el artículo completo.
            """
        } else {
            // Extract summary from title
            return """
            📰 \(title)

            🔍 Resumen rápido:
            Artículo disponible para lectura completa en la fuente original.

            💡 Sugerencia: Lee el artículo completo en el navegador para obtener toda la información y contexto.

            ℹ️ El resumen detallado está disponible cuando abres artículos directamente desde la lista de noticias.
            """
        }
    }

    private func shareArticle() {
        #if os(iOS)
        guard let urlObj = URL(string: url) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [title, urlObj],
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
