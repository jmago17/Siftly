//
//  SmartFeedsManagerView.swift
//  RSS RAIder
//

import SwiftUI

struct SmartFeedsManagerView: View {
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @Binding var selectedSmartFeedID: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var showingAdd = false
    @State private var smartFeedToEdit: SmartFeed?

    private var sortedSmartFeeds: [SmartFeed] {
        smartFeedsViewModel.smartFeeds.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind == .favorites
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Seleccionar") {
                    Button {
                        selectedSmartFeedID = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("Todos los feeds")
                            Spacer()
                            if selectedSmartFeedID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    ForEach(sortedSmartFeeds.filter { $0.isEnabled }) { smartFeed in
                        Button {
                            selectedSmartFeedID = smartFeed.id
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: smartFeed.iconSystemName)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(smartFeed.name)
                                        .font(.headline)
                                    Text("\(smartFeed.feedIDs.isEmpty ? feedsViewModel.feeds.count : smartFeed.feedIDs.count) feeds")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedSmartFeedID == smartFeed.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Gestionar") {
                    ForEach(sortedSmartFeeds) { smartFeed in
                        Button {
                            smartFeedToEdit = smartFeed
                        } label: {
                            HStack {
                                Image(systemName: smartFeed.iconSystemName)
                                    .foregroundColor(.blue)
                                Text(smartFeed.name)
                                Spacer()
                                Image(systemName: "pencil")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            let feed = sortedSmartFeeds[index]
                            guard feed.kind != .favorites else { return }
                            smartFeedsViewModel.deleteSmartFeed(id: feed.id)
                            if selectedSmartFeedID == feed.id {
                                selectedSmartFeedID = nil
                            }
                        }
                    }
                }
            }
            .navigationTitle("Smart Feeds")
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
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                SmartFeedEditorView(
                    smartFeedsViewModel: smartFeedsViewModel,
                    feedsViewModel: feedsViewModel,
                    smartFeed: nil,
                    allowsEmptyFeeds: false
                )
            }
            .sheet(item: $smartFeedToEdit) { smartFeed in
                SmartFeedEditorView(
                    smartFeedsViewModel: smartFeedsViewModel,
                    feedsViewModel: feedsViewModel,
                    smartFeed: smartFeed,
                    allowsEmptyFeeds: smartFeed.kind == .favorites
                )
            }
        }
    }
}

struct SmartFeedEditorView: View {
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    let smartFeed: SmartFeed?
    let allowsEmptyFeeds: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedFeedIDs = Set<UUID>()
    @State private var showImagesInList = true
    @State private var filters = ArticleFilterOptions()
    @State private var iconSystemName = "sparkles"

    private var sortedFeeds: [RSSFeed] {
        feedsViewModel.feeds.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre del smart feed", text: $name)
                        #if os(iOS)
                        .textContentType(.none)
                        #endif
                }

                Section("Feeds") {
                    if sortedFeeds.isEmpty {
                        Text("No hay feeds disponibles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        if allowsEmptyFeeds {
                            Text("Si no seleccionas ninguno, se incluirán todos los feeds.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ForEach(sortedFeeds) { feed in
                            Toggle(feed.name, isOn: Binding(
                                get: { selectedFeedIDs.contains(feed.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedFeedIDs.insert(feed.id)
                                    } else {
                                        selectedFeedIDs.remove(feed.id)
                                    }
                                }
                            ))
                        }
                    }
                }

                Section("Icono") {
                    SymbolPicker(selectedSymbol: $iconSystemName)
                }

                Section("Imagenes") {
                    Toggle("Mostrar imagenes en listas", isOn: $showImagesInList)
                }

                ArticleFilterOptionsView(filters: $filters)
            }
            .navigationTitle(smartFeed == nil ? "Nuevo Smart Feed" : "Editar Smart Feed")
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
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let smartFeed = smartFeed {
                    name = smartFeed.name
                    selectedFeedIDs = Set(smartFeed.feedIDs)
                    showImagesInList = smartFeed.showImagesInList
                    filters = smartFeed.filters
                    iconSystemName = smartFeed.iconSystemName
                }
            }
        }
    }

    private var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if allowsEmptyFeeds {
            return hasName
        }
        return hasName && !selectedFeedIDs.isEmpty
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if var existing = smartFeed {
            existing.name = trimmed
            existing.feedIDs = Array(selectedFeedIDs)
            existing.showImagesInList = showImagesInList
            existing.filters = filters
            existing.iconSystemName = iconSystemName
            smartFeedsViewModel.updateSmartFeed(existing)
        } else {
            var newFeed = SmartFeed(name: trimmed, feedIDs: Array(selectedFeedIDs))
            newFeed.showImagesInList = showImagesInList
            newFeed.filters = filters
            newFeed.iconSystemName = iconSystemName
            smartFeedsViewModel.addSmartFeed(newFeed)
        }
        dismiss()
    }
}

private struct SymbolPicker: View {
    @Binding var selectedSymbol: String

    private let symbols = [
        "sparkles", "star.fill", "tray.full", "newspaper",
        "bolt.fill", "brain.head.profile", "bookmark.fill", "flame.fill",
        "globe", "mic.fill", "bell.fill", "paperplane.fill",
        "chart.bar.fill", "chart.line.uptrend.xyaxis", "bubble.left.and.bubble.right.fill", "checkmark.seal.fill",
        "folder.fill", "tag.fill", "lightbulb.fill", "person.crop.circle.fill",
        "leaf.fill", "moon.fill", "sun.max.fill", "clock.fill"
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 32), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: selectedSymbol)
                    .font(.title3)
                    .frame(width: 28)
                TextField("SF Symbol", text: $selectedSymbol)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    #endif
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(symbols, id: \.self) { symbol in
                    Button {
                        selectedSymbol = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.title3)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedSymbol == symbol ? Color.blue.opacity(0.2) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                }
            }
        }
    }
}

#Preview {
    SmartFeedsManagerView(
        smartFeedsViewModel: SmartFeedsViewModel(),
        feedsViewModel: FeedsViewModel(),
        selectedSmartFeedID: .constant(nil)
    )
}
