//
//  OPMLImportExportView.swift
//  RSS RAIder
//

import SwiftUI
import UniformTypeIdentifiers

struct OPMLImportExportView: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("OPML (Outline Processor Markup Language) es un formato estándar para exportar e importar listas de feeds RSS.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Acerca de OPML")
                }

                Section {
                    Button {
                        importOPML()
                    } label: {
                        Label("Importar desde OPML", systemImage: "square.and.arrow.down")
                    }

                    Text("Importa feeds desde un archivo OPML. Los feeds duplicados serán ignorados.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Importar")
                }

                Section {
                    Button {
                        exportOPML()
                    } label: {
                        Label("Exportar a OPML", systemImage: "square.and.arrow.up")
                    }

                    if !feedsViewModel.feeds.isEmpty {
                        Text("\(feedsViewModel.feeds.count) feeds serán exportados")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Exportar")
                }
            }
            .navigationTitle("Importar/Exportar OPML")
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
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType(filenameExtension: "opml") ?? .xml],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: OPMLDocument(opmlString: exportOPMLString()),
                contentType: UTType(filenameExtension: "opml") ?? .xml,
                defaultFilename: "rssfilter-feeds.opml"
            ) { result in
                handleExport(result)
            }
            .alert("OPML", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func importOPML() {
        showingImporter = true
    }

    private func exportOPML() {
        if feedsViewModel.feeds.isEmpty {
            alertMessage = "No hay feeds para exportar"
            showingAlert = true
            return
        }

        showingExporter = true
    }

    private func exportOPMLString() -> String {
        return OPMLService.exportToOPML(feeds: feedsViewModel.feeds)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let feeds = OPMLService.importFromOPMLFile(url: url)

            if feeds.isEmpty {
                alertMessage = "No se encontraron feeds en el archivo OPML"
                showingAlert = true
                return
            }

            var importedCount = 0
            for feed in feeds {
                // Only add if not duplicate
                if !feedsViewModel.feeds.contains(where: { $0.url == feed.url }) {
                    feedsViewModel.addFeed(feed)
                    importedCount += 1
                }
            }

            alertMessage = "Se importaron \(importedCount) feeds (\(feeds.count - importedCount) duplicados ignorados)"
            showingAlert = true

        case .failure(let error):
            alertMessage = "Error al importar: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertMessage = "Feeds exportados exitosamente a \(url.lastPathComponent)"
            showingAlert = true

        case .failure(let error):
            alertMessage = "Error al exportar: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - OPML Document

struct OPMLDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "opml") ?? .xml]
    }

    var opmlString: String

    init(opmlString: String) {
        self.opmlString = opmlString
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.opmlString = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = opmlString.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    OPMLImportExportView(feedsViewModel: FeedsViewModel())
}
