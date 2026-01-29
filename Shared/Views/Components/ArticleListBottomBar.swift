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
    @State private var showingScorePicker = false
    @State private var showingActionsMenu = false

    var body: some View {
        Group {
            #if os(iOS)
            HStack(spacing: 12) {
                // All articles button
                GlassButton(
                    systemName: "tray.full",
                    isActive: readFilter == .all,
                    tint: readFilter == .all ? .blue : .secondary
                ) {
                    readFilter = .all
                }

                // Unread only button
                GlassButton(
                    systemName: "envelope.badge",
                    isActive: readFilter == .unread,
                    tint: readFilter == .unread ? .blue : .secondary
                ) {
                    readFilter = .unread
                }

                // Sort order toggle (if provided)
                if let sortBinding = sortOrder {
                    GlassButton(
                        systemName: sortBinding.wrappedValue.iconName,
                        isActive: true,
                        tint: .blue
                    ) {
                        sortBinding.wrappedValue = sortBinding.wrappedValue == .score ? .chronological : .score
                    }
                }

                // Starred toggle
                GlassButton(
                    systemName: showStarredOnly ? "star.fill" : "star",
                    isActive: showStarredOnly,
                    tint: showStarredOnly ? .yellow : .secondary
                ) {
                    showStarredOnly.toggle()
                }

                // Score filter
                GlassPillButton(isActive: minScoreFilter > 0, tint: minScoreFilter > 0 ? .blue : .secondary) {
                    showingScorePicker = true
                } label: {
                    HStack(spacing: 4) {
                        if minScoreFilter > 0 {
                            Text("\(minScoreFilter)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                }

                // Actions menu (mark all as read, etc.)
                if onMarkAllAsRead != nil {
                    GlassButton(
                        systemName: "ellipsis.circle",
                        isActive: false,
                        tint: .secondary
                    ) {
                        showingActionsMenu = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .confirmationDialog("Acciones", isPresented: $showingActionsMenu) {
                if let markAllAsRead = onMarkAllAsRead {
                    Button("Marcar todo como leído") {
                        markAllAsRead()
                    }
                }
                Button("Cancelar", role: .cancel) { }
            }
            #else
            HStack(spacing: 12) {
                // All articles button
                Button {
                    readFilter = .all
                } label: {
                    Image(systemName: "tray.full")
                        .font(.title3)
                }
                .foregroundColor(readFilter == .all ? .blue : .secondary)

                // Unread only button
                Button {
                    readFilter = .unread
                } label: {
                    Image(systemName: "envelope.badge")
                        .font(.title3)
                }
                .foregroundColor(readFilter == .unread ? .blue : .secondary)

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

                // Starred toggle
                Button {
                    showStarredOnly.toggle()
                } label: {
                    Image(systemName: showStarredOnly ? "star.fill" : "star")
                        .font(.title3)
                }
                .foregroundColor(showStarredOnly ? .yellow : .secondary)

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
            #endif
        }
        .sheet(isPresented: $showingScorePicker) {
            ScoreFilterSheet(minScoreFilter: $minScoreFilter)
        }
    }
}

#if os(iOS)
private struct GlassButton: View {
    let systemName: String
    var isActive: Bool = false
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(GlassButtonStyle(isActive: isActive))
        .foregroundColor(tint)
    }
}

private struct GlassPillButton<Label: View>: View {
    var isActive: Bool = false
    var tint: Color = .secondary
    let action: () -> Void
    let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.caption)
                .frame(minWidth: 36, minHeight: 36)
        }
        .buttonStyle(GlassButtonStyle(isActive: isActive))
        .foregroundColor(tint)
    }
}

private struct GlassButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isActive ? 0.3 : 0.1), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
#endif

// MARK: - Score Filter Sheet

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
