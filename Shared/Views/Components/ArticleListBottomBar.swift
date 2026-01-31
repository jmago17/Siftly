//
//  ArticleListBottomBar.swift
//  RSS RAIder
//

import SwiftUI

enum ArticleSortOrder: String, CaseIterable {
    case score
    case chronological

    var iconName: String {
        switch self {
        case .score: return "star.circle"
        case .chronological: return "clock"
        }
    }
}

struct ArticleListBottomBar: View {
    @Binding var readFilter: ReadFilter
    @Binding var showStarredOnly: Bool
    @Binding var minScoreFilter: Int
    var sortOrder: Binding<ArticleSortOrder>?
    var searchText: Binding<String>?
    var onMarkAllAsRead: (() -> Void)?
    var onScrollToTop: (() -> Void)?

    @State private var showingScorePicker = false
    @State private var showingFilterMenu = false
    @State private var showingSearch = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        #if os(iOS)
        VStack(spacing: 8) {
            // Search bar (shown when search is active)
            if showingSearch, let searchBinding = searchText {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar artículos...", text: searchBinding)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                    if !searchBinding.wrappedValue.isEmpty {
                        Button {
                            searchBinding.wrappedValue = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button("Cancelar") {
                        searchBinding.wrappedValue = ""
                        showingSearch = false
                        isSearchFocused = false
                    }
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                // Left pill: Filter, Read toggle, Star, Sort, Score slider
                HStack(spacing: 0) {
                    // Filter button
                    Button {
                        showingFilterMenu = true
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundColor(hasActiveFilters ? .accentColor : .primary)

                    // Mark as read toggle (dot)
                    Button {
                        readFilter = readFilter == .unread ? .all : .unread
                    } label: {
                        Image(systemName: readFilter == .unread ? "circle.inset.filled" : "circle")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundColor(readFilter == .unread ? .accentColor : .primary)

                    // Star toggle
                    Button {
                        showStarredOnly.toggle()
                    } label: {
                        Image(systemName: showStarredOnly ? "star.fill" : "star")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundColor(showStarredOnly ? .yellow : .primary)

                    // Sort order toggle (score/chronological)
                    if let sort = sortOrder {
                        Button {
                            sort.wrappedValue = sort.wrappedValue == .score ? .chronological : .score
                        } label: {
                            Image(systemName: sort.wrappedValue.iconName)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                        .foregroundColor(.primary)
                    }

                    // Score filter (chevron with popup)
                    Button {
                        showingScorePicker = true
                    } label: {
                        HStack(spacing: 2) {
                            if minScoreFilter > 0 {
                                Text("\(minScoreFilter)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            Image(systemName: "chevron.up")
                                .font(.title3)
                        }
                        .frame(width: 44, height: 44)
                    }
                    .foregroundColor(minScoreFilter > 0 ? .accentColor : .primary)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )

                Spacer()

                // Actions on the right
                if let markAllAsRead = onMarkAllAsRead {
                    Button {
                        markAllAsRead()
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundColor(.accentColor)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                }

                // Search button (right)
                if searchText != nil {
                    Button {
                        showingSearch.toggle()
                        if showingSearch {
                            isSearchFocused = true
                        }
                    } label: {
                        Image(systemName: showingSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundColor(showingSearch ? .accentColor : .primary)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingScorePicker) {
            ScoreSliderSheet(minScoreFilter: $minScoreFilter)
        }
        .sheet(isPresented: $showingFilterMenu) {
            FilterMenuSheet(
                readFilter: $readFilter,
                showStarredOnly: $showStarredOnly,
                minScoreFilter: $minScoreFilter,
                sortOrder: sortOrder,
                onMarkAllAsRead: onMarkAllAsRead
            )
        }
        #else
        // macOS version
        HStack(spacing: 12) {
            // Read filter toggle
            Button {
                readFilter = readFilter == .unread ? .all : .unread
            } label: {
                Image(systemName: readFilter == .unread ? "circle.inset.filled" : "circle")
                    .font(.title2)
            }
            .foregroundColor(readFilter == .unread ? .accentColor : .secondary)

            // Starred toggle
            Button {
                showStarredOnly.toggle()
            } label: {
                Image(systemName: showStarredOnly ? "star.fill" : "star")
                    .font(.title2)
            }
            .foregroundColor(showStarredOnly ? .yellow : .secondary)

            // Sort order toggle (if provided)
            if let sortBinding = sortOrder {
                Button {
                    sortBinding.wrappedValue = sortBinding.wrappedValue == .score ? .chronological : .score
                } label: {
                    Image(systemName: sortBinding.wrappedValue.iconName)
                        .font(.title2)
                }
                .foregroundColor(.accentColor)
            }

            Divider()
                .frame(height: 24)

            // Score filter
            Button {
                showingScorePicker = true
            } label: {
                HStack(spacing: 2) {
                    if minScoreFilter > 0 {
                        Text("\(minScoreFilter)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
            }
            .foregroundColor(minScoreFilter > 0 ? .accentColor : .secondary)

            // Actions menu
            if let markAllAsRead = onMarkAllAsRead {
                Button {
                    markAllAsRead()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
        .sheet(isPresented: $showingScorePicker) {
            ScoreFilterSheet(minScoreFilter: $minScoreFilter)
        }
        #endif
    }

    private var hasActiveFilters: Bool {
        minScoreFilter > 0 || readFilter != .all || showStarredOnly
    }
}

// MARK: - Filter Menu Sheet

struct FilterMenuSheet: View {
    @Binding var readFilter: ReadFilter
    @Binding var showStarredOnly: Bool
    @Binding var minScoreFilter: Int
    var sortOrder: Binding<ArticleSortOrder>?
    var onMarkAllAsRead: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Read filter
                    Picker("Estado de lectura", selection: $readFilter) {
                        ForEach(ReadFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Starred only
                    Toggle("Solo favoritos", isOn: $showStarredOnly)
                } header: {
                    Text("Filtros")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Puntuación mínima:")
                            Spacer()
                            Text("\(minScoreFilter)")
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                        }

                        Slider(value: Binding(
                            get: { Double(minScoreFilter) },
                            set: { minScoreFilter = Int($0) }
                        ), in: 0...100, step: 10)
                    }

                    if minScoreFilter > 0 {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.accentColor)
                            Text("Solo artículos con puntuación ≥ \(minScoreFilter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Calidad")
                }

                if let sort = sortOrder {
                    Section {
                        Picker("Ordenar por", selection: sort) {
                            Text("Puntuación").tag(ArticleSortOrder.score)
                            Text("Fecha").tag(ArticleSortOrder.chronological)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Orden")
                    }
                }

                Section {
                    if let markAllAsRead = onMarkAllAsRead {
                        Button {
                            markAllAsRead()
                            dismiss()
                        } label: {
                            Label("Marcar todo como leído", systemImage: "checkmark.circle")
                        }
                    }

                    Button(role: .destructive) {
                        readFilter = .all
                        showStarredOnly = false
                        minScoreFilter = 0
                    } label: {
                        Label("Restablecer filtros", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!hasActiveFilters)
                } header: {
                    Text("Acciones")
                }
            }
            .navigationTitle("Filtros")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private var hasActiveFilters: Bool {
        minScoreFilter > 0 || readFilter != .all || showStarredOnly
    }

    private var scoreColor: Color {
        switch minScoreFilter {
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
        }
    }
}

// MARK: - Score Slider Sheet (compact popup for quick score selection)

struct ScoreSliderSheet: View {
    @Binding var minScoreFilter: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Puntuación mínima")
                            .font(.headline)
                        Spacer()
                        Text("\(minScoreFilter)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor)
                    }

                    Slider(value: Binding(
                        get: { Double(minScoreFilter) },
                        set: { minScoreFilter = Int($0) }
                    ), in: 0...100, step: 10)
                    .tint(scoreColor)

                    // Quick select buttons
                    HStack(spacing: 8) {
                        ForEach([0, 30, 50, 70, 90], id: \.self) { score in
                            Button {
                                minScoreFilter = score
                            } label: {
                                Text(score == 0 ? "Todos" : "\(score)+")
                                    .font(.caption)
                                    .fontWeight(minScoreFilter == score ? .bold : .regular)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(minScoreFilter == score ? scoreColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                    .foregroundColor(minScoreFilter == score ? scoreColor : .secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Filtro de Calidad")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.height(250)])
        #endif
    }

    private var scoreColor: Color {
        switch minScoreFilter {
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
        }
    }
}

// MARK: - Score Filter Sheet (for macOS)

struct ScoreFilterSheet: View {
    @Binding var minScoreFilter: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Puntuación mínima:")
                            Spacer()
                            Text("\(minScoreFilter)")
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                        }

                        Slider(value: Binding(
                            get: { Double(minScoreFilter) },
                            set: { minScoreFilter = Int($0) }
                        ), in: 0...100, step: 10)
                    }

                    if minScoreFilter > 0 {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.accentColor)
                            Text("Solo se mostrarán artículos con puntuación ≥ \(minScoreFilter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Filtro de calidad")
                } footer: {
                    Text("Filtra artículos por su puntuación de calidad (0 = mostrar todos)")
                }

                Section {
                    Button(role: .destructive) {
                        minScoreFilter = 0
                    } label: {
                        Label("Restablecer filtro", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(minScoreFilter == 0)
                }
            }
            .navigationTitle("Filtro de Puntuación")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    private var scoreColor: Color {
        switch minScoreFilter {
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ArticleListBottomBar(
            readFilter: .constant(.all),
            showStarredOnly: .constant(false),
            minScoreFilter: .constant(0)
        )
    }
}
