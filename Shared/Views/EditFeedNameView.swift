//
//  EditFeedNameView.swift
//  RSS RAIder
//

import SwiftUI

struct EditFeedNameView: View {
    let feed: RSSFeed
    @ObservedObject var feedsViewModel: FeedsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var feedName: String
    @State private var openInSafariReader: Bool
    @State private var showImagesInList: Bool
    @State private var autoMarkReadEnabled: Bool
    @State private var autoMarkReadDays: Int

    private let dayOptions = [1, 2, 3, 5, 7, 14, 30]

    init(feed: RSSFeed, feedsViewModel: FeedsViewModel) {
        self.feed = feed
        self.feedsViewModel = feedsViewModel
        _feedName = State(initialValue: feed.name)
        _openInSafariReader = State(initialValue: feed.openInSafariReader)
        _showImagesInList = State(initialValue: feed.showImagesInList)
        _autoMarkReadEnabled = State(initialValue: feed.autoMarkReadAfterDays != nil)
        _autoMarkReadDays = State(initialValue: feed.autoMarkReadAfterDays ?? 7)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre del feed", text: $feedName)
                        #if os(iOS)
                        .textContentType(.none)
                        #endif
                } header: {
                    Text("Nombre")
                } footer: {
                    Text("Cambia el nombre con el que se muestra este feed.")
                }

                Section {
                    Toggle("Abrir en Safari (modo lectura)", isOn: $openInSafariReader)
                } header: {
                    Text("Apertura")
                } footer: {
                    Text("Si esta activado, los articulos de este feed se abren en Safari con modo lectura.")
                }

                Section {
                    Toggle("Mostrar imagenes en listas", isOn: $showImagesInList)
                } header: {
                    Text("Imagenes")
                } footer: {
                    Text("Muestra una miniatura del articulo en las listas de noticias.")
                }

                Section {
                    Toggle("Marcar como leído automáticamente", isOn: $autoMarkReadEnabled)

                    if autoMarkReadEnabled {
                        Picker("Después de", selection: $autoMarkReadDays) {
                            ForEach(dayOptions, id: \.self) { days in
                                Text(days == 1 ? "1 día" : "\(days) días").tag(days)
                            }
                        }
                    }
                } header: {
                    Text("Lectura automática")
                } footer: {
                    Text("Los artículos de este feed se marcarán como leídos automáticamente después del tiempo especificado.")
                }
            }
            .navigationTitle("Ajustes del Feed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(feedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        var updated = feed
        updated.name = feedName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.openInSafariReader = openInSafariReader
        updated.showImagesInList = showImagesInList
        updated.autoMarkReadAfterDays = autoMarkReadEnabled ? autoMarkReadDays : nil
        feedsViewModel.updateFeed(updated)
        dismiss()
    }
}

#Preview {
    EditFeedNameView(
        feed: RSSFeed(name: "Ejemplo", url: "https://example.com/rss"),
        feedsViewModel: FeedsViewModel()
    )
}
