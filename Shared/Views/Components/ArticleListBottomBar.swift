//
//  ArticleListBottomBar.swift
//  RSS RAIder
//

import SwiftUI

struct ArticleListBottomBar: View {
    @Binding var readFilter: ReadFilter
    @Binding var showStarredOnly: Bool
    @Binding var minScoreFilter: Int
    @State private var showingNavMenu = false
    @State private var showingScorePicker = false

    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @ObservedObject var newsViewModel: NewsViewModel

    var body: some View {
        Group {
            #if os(iOS)
            paneContainer {
                HStack(spacing: 10) {
                    PaneIconButton(systemName: "line.3.horizontal") {
                        showingNavMenu = true
                    }

                    Picker("", selection: $readFilter) {
                        Text("Todas").tag(ReadFilter.all)
                        Text("No leídas").tag(ReadFilter.unread)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 170)

                    PaneIconButton(
                        systemName: showStarredOnly ? "star.fill" : "star",
                        isActive: showStarredOnly,
                        tint: showStarredOnly ? .yellow : .secondary
                    ) {
                        showStarredOnly.toggle()
                    }

                    PanePillButton(isActive: minScoreFilter > 0, tint: minScoreFilter > 0 ? .blue : .secondary) {
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
                }
            }
            #else
            HStack(spacing: 12) {
                // Hamburger menu
                Button {
                    showingNavMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3)
                }

                Divider()
                    .frame(height: 24)

                // Read filter toggle
                Picker("", selection: $readFilter) {
                    Text("Todas").tag(ReadFilter.all)
                    Text("No leídas").tag(ReadFilter.unread)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 140)

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
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .top) {
                Divider()
            }
            #endif
        }
        .sheet(isPresented: $showingNavMenu) {
            NavigationMenuSheet(
                feedsViewModel: feedsViewModel,
                smartFoldersViewModel: smartFoldersViewModel,
                smartFeedsViewModel: smartFeedsViewModel,
                newsViewModel: newsViewModel
            )
        }
        .sheet(isPresented: $showingScorePicker) {
            ScoreFilterSheet(minScoreFilter: $minScoreFilter)
        }
    }

    #if os(iOS)
    private func paneContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.4), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .background(
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
    }
    #endif
}

#if os(iOS)
private struct PaneIconButton: View {
    let systemName: String
    var isActive: Bool = false
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(PaneButtonStyle(isActive: isActive))
        .foregroundColor(tint)
    }
}

private struct PanePillButton<Label: View>: View {
    var isActive: Bool = false
    var tint: Color = .secondary
    let action: () -> Void
    let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.caption)
                .frame(minWidth: 28, minHeight: 28)
        }
        .buttonStyle(PaneButtonStyle(isActive: isActive))
        .foregroundColor(tint)
    }
}

private struct PaneButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: isActive ? .tertiarySystemFill : .systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.4), lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
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
            minScoreFilter: .constant(0),
            feedsViewModel: FeedsViewModel(),
            smartFoldersViewModel: SmartFoldersViewModel(),
            smartFeedsViewModel: SmartFeedsViewModel(),
            newsViewModel: NewsViewModel()
        )
    }
}
