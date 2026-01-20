//
//  NewsFeedControlsView.swift
//  RSS RAIder
//

import SwiftUI

struct NewsFeedControlsView: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @Environment(\.dismiss) private var dismiss

    private var sortedFeeds: [RSSFeed] {
        feedsViewModel.feeds.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            if sortedFeeds.isEmpty {
                ContentUnavailableView {
                    Label("Sin feeds", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Agrega feeds para gestionar silencios y prioridades")
                }
            } else {
                Form {
                    Section {
                        Text("Silencia feeds que no quieras ver en la pantalla de noticias. La prioridad suma puntos a las noticias de ese feed.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    Section {
                        ForEach(sortedFeeds) { feed in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(feed.name)
                                    .font(.headline)

                                Toggle("Silenciar en noticias", isOn: Binding(
                                    get: { feed.isMutedInNews },
                                    set: { feedsViewModel.setFeedMutedInNews(id: feed.id, isMuted: $0) }
                                ))

                                Stepper(value: Binding(
                                    get: { feed.priorityBoost },
                                    set: { feedsViewModel.setFeedPriorityBoost(id: feed.id, boost: $0) }
                                ), in: 0...100, step: 5) {
                                    Text("Prioridad: +\(feed.priorityBoost)")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Feeds")
                    } footer: {
                        Text("Ejemplo: +100 hace que ese feed tenga prioridad maxima.")
                    }
                }
            }
        }
        .navigationTitle("Fuentes")
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
}

#Preview {
    NavigationStack {
        NewsFeedControlsView(feedsViewModel: FeedsViewModel())
    }
}
