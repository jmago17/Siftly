//
//  AddSmartFolderView.swift
//  RSS RAIder
//

import SwiftUI

struct AddSmartFolderView: View {
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    let smartFolder: SmartFolder?
    @Environment(\.dismiss) private var dismiss

    @State private var folderName: String
    @State private var folderDescription: String
    @State private var filters: ArticleFilterOptions

    init(smartFoldersViewModel: SmartFoldersViewModel, smartFolder: SmartFolder? = nil) {
        self.smartFoldersViewModel = smartFoldersViewModel
        self.smartFolder = smartFolder
        _folderName = State(initialValue: smartFolder?.name ?? "")
        _folderDescription = State(initialValue: smartFolder?.description ?? "")
        _filters = State(initialValue: smartFolder?.filters ?? ArticleFilterOptions())
    }

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
                    Text("Por ejemplo: Tecnología, Política, Deportes")
                }

                Section {
                    TextEditor(text: $folderDescription)
                        .frame(minHeight: 100)
                } header: {
                    Text("Descripción")
                } footer: {
                    Text("Describe qué tipo de noticias debe contener esta carpeta. La IA usará esta descripción para clasificar artículos automáticamente.")
                }

                ArticleFilterOptionsView(filters: $filters)

                Section {
                    Text("Ejemplos de descripciones:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        ExampleDescription(
                            title: "Tecnología",
                            description: "Noticias sobre tecnología, software, hardware, inteligencia artificial, programación, gadgets"
                        )

                        ExampleDescription(
                            title: "Deportes",
                            description: "Noticias sobre fútbol, baloncesto, tenis, Fórmula 1, deportes de motor"
                        )

                        ExampleDescription(
                            title: "Política Local",
                            description: "Noticias sobre política local, ayuntamientos, comunidades autónomas, elecciones locales"
                        )
                    }
                    .font(.caption2)
                }
            }
            .navigationTitle(smartFolder == nil ? "Nueva Carpeta Inteligente" : "Editar Carpeta Inteligente")
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
                    Button(smartFolder == nil ? "Crear" : "Guardar") {
                        saveFolder()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !folderName.isEmpty && !folderDescription.isEmpty
    }

    private func saveFolder() {
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = folderDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if var existing = smartFolder {
            existing.name = trimmedName
            existing.description = trimmedDescription
            existing.filters = filters
            smartFoldersViewModel.updateFolder(existing)
        } else {
            var folder = SmartFolder(name: trimmedName, description: trimmedDescription)
            folder.filters = filters
            smartFoldersViewModel.addFolder(folder)
        }
        dismiss()
    }
}

struct ExampleDescription: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .fontWeight(.semibold)
            Text(description)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddSmartFolderView(smartFoldersViewModel: SmartFoldersViewModel())
}
