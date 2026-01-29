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
    var onMarkAllAsRead: (() -> Void)?
    var onScrollToTop: (() -> Void)?
    var onSearch: (() -> Void)?

    @State private var showingScorePicker = false
    @State private var showingActionsMenu = false
    @State private var showingFilterMenu = false

    var body: some View {
        #if os(iOS)
        HStack(spacing: 12) {
            // Left pill: Menu, Mark Read, Star, Scroll Up
            HStack(spacing: 0) {
                // Menu button (hamburger)
                Button {
                    showingActionsMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.body)
                        .frame(width: 40, height: 40)
                }
                .foregroundColor(.primary)

                // Mark as read toggle (dot)
                Button {
                    // Toggle between all and unread
                    readFilter = readFilter == .unread ? .all : .unread
                } label: {
                    Image(systemName: readFilter == .unread ? "circle.inset.filled" : "circle")
                        .font(.body)
                        .frame(width: 40, height: 40)
                }
                .foregroundColor(readFilter == .unread ? .blue : .primary)

                // Star toggle
                Button {
                    showStarredOnly.toggle()
                } label: {
                    Image(systemName: showStarredOnly ? "star.fill" : "star")
                        .font(.body)
                        .frame(width: 40, height: 40)
                }
                .foregroundColor(showStarredOnly ? .yellow : .primary)

                // Scroll to top (arrow up)
                Button {
                    onScrollToTop?()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.body)
                        .frame(width: 40, height: 40)
                }
                .foregroundColor(.primary)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )

            Spacer()

            // Search button (center)
            Button {
                onSearch?()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .frame(width: 44, height: 44)
            }
            .foregroundColor(.primary)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )

            Spacer()

            // Filter button (right)
            Button {
                showingFilterMenu = true
            } label: {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.body)
                    .frame(width: 44, height: 44)
            }
            .foregroundColor(hasActiveFilters ? .blue : .primary)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .confirmationDialog("Acciones", isPresented: $showingActionsMenu) {
            if let markAllAsRead = onMarkAllAsRead {
                Button("Marcar todo como leído") {
                    markAllAsRead()
                }
            }
            if let sort = sortOrder {
                Button(sort.wrappedValue == .score ? "Ordenar por fecha" : "Ordenar por puntuación") {
                    sort.wrappedValue = sort.wrappedValue == .score ? .chronological : .score
                }
            }
            Button("Cancelar", role: .cancel) { }
        }
        .sheet(isPresented: $showingFilterMenu) {
            FilterMenuSheet(
                readFilter: $readFilter,
                showStarredOnly: $showStarredOnly,
                minScoreFilter: $minScoreFilter,
                sortOrder: sortOrder
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
                    .font(.title3)
            }
            .foregroundColor(readFilter == .unread ? .blue : .secondary)

            // Starred toggle
            Button {
                showStarredOnly.toggle()
            } label: {
                Image(systemName: showStarredOnly ? "star.fill" : "star")
                    .font(.title3)
            }
            .foregroundColor(showStarredOnly ? .yellow : .secondary)

            // Sort order toggle (if provided)
            if let sortBinding = sortOrder {
                Button {
                    sortBinding.wrappedValue = sortBinding.wrappedValue == .score ? .chronological : .score
                } label: {
                    Image(systemName: sortBinding.wrappedValue.iconName)
                        .font(.title3)
                }
                .foregroundColor(.blue)
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
            .foregroundColor(minScoreFilter > 0 ? .blue : .secondary)

            // Actions menu
            if let markAllAsRead = onMarkAllAsRead {
                Button {
                    markAllAsRead()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
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
                                .foregroundColor(.blue)
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
                    Button(role: .destructive) {
                        readFilter = .all
                        showStarredOnly = false
                        minScoreFilter = 0
                    } label: {
                        Label("Restablecer filtros", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!hasActiveFilters)
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
        .presentationDetents([.medium])
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
                                .foregroundColor(.blue)
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
