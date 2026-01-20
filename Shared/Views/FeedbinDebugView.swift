//
//  FeedbinDebugView.swift
//  RSS RAIder
//

import SwiftUI

struct FeedbinDebugView: View {
    let feed: RSSFeed

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var subscriptionTitle: String?
    @State private var entries: [FeedbinEntry] = []

    var body: some View {
        NavigationStack {
            Group {
                if !FeedbinService.shared.hasCredentials {
                    ContentUnavailableView {
                        Label("Feedbin no configurado", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("Configura tus credenciales de Feedbin en Ajustes para cargar este feed.")
                    }
                } else if isLoading {
                    ProgressView("Cargando entradas de Feedbin...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    ContentUnavailableView {
                        Label("Error de Feedbin", systemImage: "xmark.octagon")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Reintentar") {
                            Task { await loadEntries() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section("Feed") {
                            Text(feed.name)
                                .font(.headline)
                            Text(feed.url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            if let subscriptionTitle = subscriptionTitle, !subscriptionTitle.isEmpty {
                                Text("Feedbin: \(subscriptionTitle)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Section("Entradas") {
                            if entries.isEmpty {
                                Text("Feedbin no devolvio entradas.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(entries) { entry in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(entry.title ?? "Untitled")
                                            .font(.headline)

                                        if let preview = entryPreview(entry), !preview.isEmpty {
                                            Text(preview)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(3)
                                        }

                                        HStack(spacing: 8) {
                                            if let published = entry.published {
                                                Text(published, style: .date)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }

                                            if let urlString = entry.url, let url = URL(string: urlString) {
                                                Button("Abrir") {
                                                    openURL(url)
                                                }
                                                .font(.caption2)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Feedbin")
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
                    Button {
                        Task { await loadEntries() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!FeedbinService.shared.hasCredentials)
                }
            }
            .task {
                await loadEntries()
            }
        }
    }

    private func loadEntries() async {
        guard FeedbinService.shared.hasCredentials else { return }
        isLoading = true
        errorMessage = nil

        do {
            let result = try await FeedbinService.shared.fetchEntries(for: feed.url)
            subscriptionTitle = result.0.title
            entries = result.1
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func entryPreview(_ entry: FeedbinEntry) -> String? {
        let source = entry.summary ?? entry.content
        guard let source = source, !source.isEmpty else { return nil }
        let stripped = HTMLCleaner.stripTags(source)
        let decoded = HTMLCleaner.decodeHTMLEntities(stripped)
        let cleaned = decoded.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let maxLength = 260
        if cleaned.count > maxLength {
            let preview = String(cleaned.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(preview)..."
        }
        return cleaned
    }
}

#Preview {
    FeedbinDebugView(feed: RSSFeed(name: "Example Feed", url: "https://example.com/feed.xml"))
}
