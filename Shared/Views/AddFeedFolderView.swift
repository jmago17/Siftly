//
//  AddFeedFolderView.swift
//  RSS RAIder
//

import SwiftUI

struct AddFeedFolderView: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var folderName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre de la carpeta", text: $folderName)
                        #if os(iOS)
                        .textContentType(.none)
                        #endif
                } header: {
                    Text("Nombre")
                } footer: {
                    Text("Agrupa feeds por tema o fuente")
                }
            }
            .navigationTitle("Nueva Carpeta")
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
                    Button("Crear") {
                        saveFolder()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveFolder() {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let folder = FeedFolder(name: trimmed)
        feedsViewModel.addFeedFolder(folder)
        dismiss()
    }
}

#Preview {
    AddFeedFolderView(feedsViewModel: FeedsViewModel())
}
