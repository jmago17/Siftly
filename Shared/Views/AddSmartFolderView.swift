//
//  AddSmartFolderView.swift
//  RSSFilter
//

import SwiftUI

struct AddSmartFolderView: View {
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var folderName = ""
    @State private var folderDescription = ""

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
            .navigationTitle("Nueva Carpeta Inteligente")
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
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !folderName.isEmpty && !folderDescription.isEmpty
    }

    private func saveFolder() {
        let folder = SmartFolder(name: folderName, description: folderDescription)
        smartFoldersViewModel.addFolder(folder)
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
