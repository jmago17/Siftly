//
//  SmartTagsListView.swift
//  RSS RAIder
//

import SwiftUI

struct SmartTagsListView: View {
    @ObservedObject var smartTagsViewModel: SmartTagsViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @State private var showingAddTag = false
    @State private var tagToEdit: SmartTag?

    var body: some View {
        List {
            Section {
                ForEach(smartTagsViewModel.smartTags) { tag in
                    SmartTagRow(
                        tag: tag,
                        matchCount: matchCount(for: tag),
                        onToggle: {
                            smartTagsViewModel.toggleTag(id: tag.id)
                        },
                        onEdit: {
                            tagToEdit = tag
                        }
                    )
                    .contextMenu {
                        Button {
                            tagToEdit = tag
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }

                        Button {
                            smartTagsViewModel.toggleTag(id: tag.id)
                        } label: {
                            Label(
                                tag.isEnabled ? "Desactivar" : "Activar",
                                systemImage: tag.isEnabled ? "eye.slash" : "eye"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                            smartTagsViewModel.deleteTag(id: tag.id)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        smartTagsViewModel.deleteTag(id: smartTagsViewModel.smartTags[index].id)
                    }
                }
                .onMove { source, destination in
                    smartTagsViewModel.moveTags(from: source, to: destination)
                }
            } header: {
                Text("Etiquetas Inteligentes")
            } footer: {
                Text("Arrastra para reordenar. Las etiquetas con mayor prioridad se procesan primero.")
            }
        }
        .navigationTitle("Etiquetas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTag = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAddTag) {
            AddSmartTagView(smartTagsViewModel: smartTagsViewModel)
        }
        .sheet(item: $tagToEdit) { tag in
            AddSmartTagView(smartTagsViewModel: smartTagsViewModel, existingTag: tag)
        }
    }

    private func matchCount(for tag: SmartTag) -> Int {
        newsViewModel.newsItems.filter { $0.tagIDs.contains(tag.id) }.count
    }
}

struct SmartTagRow: View {
    let tag: SmartTag
    let matchCount: Int
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(tag.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(tag.name)
                        .font(.headline)
                        .foregroundColor(tag.isEnabled ? .primary : .secondary)

                    if matchCount > 0 {
                        Text("\(matchCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tag.color.opacity(0.2))
                            .foregroundColor(tag.color)
                            .clipShape(Capsule())
                    }
                }

                Text(tag.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text("Prioridad: \(tag.priority)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { tag.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

struct AddSmartTagView: View {
    @ObservedObject var smartTagsViewModel: SmartTagsViewModel
    @Environment(\.dismiss) private var dismiss
    var existingTag: SmartTag?

    @State private var name = ""
    @State private var description = ""
    @State private var priority = 50
    @State private var selectedColor = "blue"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)

                    TextField("Descripción (palabras clave separadas por comas)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Información")
                } footer: {
                    Text("Usa palabras clave que describan los artículos que deben tener esta etiqueta. Ejemplo: tecnología, software, hardware, inteligencia artificial")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Prioridad")
                            Spacer()
                            Text("\(priority)")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(priority) },
                            set: { priority = Int($0) }
                        ), in: 0...100, step: 5)
                    }
                } header: {
                    Text("Prioridad")
                } footer: {
                    Text("Las etiquetas con mayor prioridad se procesan primero por la IA.")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(SmartTag.availableColors, id: \.self) { colorName in
                            Button {
                                selectedColor = colorName
                            } label: {
                                Circle()
                                    .fill(colorFromName(colorName))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if selectedColor == colorName {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .font(.caption.bold())
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }

                if existingTag == nil {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ejemplos de etiquetas:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(SmartTag.defaultTags.prefix(4)) { tag in
                                Button {
                                    name = tag.name
                                    description = tag.description
                                    priority = tag.priority
                                    selectedColor = tag.colorName
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(tag.color)
                                            .frame(width: 8, height: 8)
                                        Text(tag.name)
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingTag == nil ? "Nueva Etiqueta" : "Editar Etiqueta")
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
                        saveTag()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let tag = existingTag {
                    name = tag.name
                    description = tag.description
                    priority = tag.priority
                    selectedColor = tag.colorName
                }
            }
        }
    }

    private func saveTag() {
        if let existingTag = existingTag {
            var updated = existingTag
            updated.name = name.trimmingCharacters(in: .whitespaces)
            updated.description = description.trimmingCharacters(in: .whitespaces)
            updated.priority = priority
            updated.colorName = selectedColor
            smartTagsViewModel.updateTag(updated)
        } else {
            let newTag = SmartTag(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                priority: priority,
                colorName: selectedColor
            )
            smartTagsViewModel.addTag(newTag)
        }
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        default: return .blue
        }
    }
}

#Preview {
    NavigationStack {
        SmartTagsListView(
            smartTagsViewModel: SmartTagsViewModel(),
            newsViewModel: NewsViewModel()
        )
    }
}
