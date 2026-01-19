//
//  SmartFoldersListView.swift
//  RSSFilter
//

import SwiftUI

struct SmartFoldersListView: View {
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @State private var showingAddFolder = false
    @State private var selectedFolderID: UUID?

    var body: some View {
        Group {
            if smartFoldersViewModel.smartFolders.isEmpty {
                ContentUnavailableView {
                    Label("No hay carpetas inteligentes", systemImage: "folder")
                } description: {
                    Text("Crea carpetas inteligentes para organizar tus noticias automáticamente")
                } actions: {
                    Button("Crear Carpeta") {
                        showingAddFolder = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(smartFoldersViewModel.smartFolders) { folder in
                        SmartFolderDetailView(
                            folder: folder,
                            newsItems: newsViewModel.getNewsItems(smartFolderID: folder.id),
                            smartFoldersViewModel: smartFoldersViewModel
                        )
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            smartFoldersViewModel.deleteFolder(id: smartFoldersViewModel.smartFolders[index].id)
                        }
                    }
                }
            }
        }
        .navigationTitle("Carpetas Inteligentes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFolder = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFolder) {
            AddSmartFolderView(smartFoldersViewModel: smartFoldersViewModel)
        }
        .onAppear {
            // Update match counts when view appears
            smartFoldersViewModel.updateMatchCounts(newsItems: newsViewModel.newsItems)
        }
    }
}

struct SmartFolderDetailView: View {
    let folder: SmartFolder
    let newsItems: [NewsItem]
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @State private var isExpanded = false
    @State private var selectedNewsItem: NewsItem?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if newsItems.isEmpty {
                Text("No hay artículos en esta carpeta")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(newsItems.prefix(5)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline)
                            .lineLimit(2)

                        Text(item.feedName)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNewsItem = item
                    }
                }

                if newsItems.count > 5 {
                    Text("y \(newsItems.count - 5) más...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: folder.isEnabled ? "folder.fill" : "folder")
                            .foregroundColor(folder.isEnabled ? .blue : .gray)

                        Text(folder.name)
                            .font(.headline)
                    }

                    Text(folder.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if folder.matchCount > 0 {
                        Text("\(folder.matchCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }

                    Toggle("", isOn: Binding(
                        get: { folder.isEnabled },
                        set: { _ in smartFoldersViewModel.toggleFolder(id: folder.id) }
                    ))
                    .labelsHidden()
                }
            }
        }
        .sheet(item: $selectedNewsItem) { item in
            ArticleReaderView(newsItem: item)
            #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            #endif
        }
    }
}

#Preview {
    NavigationStack {
        SmartFoldersListView(
            smartFoldersViewModel: SmartFoldersViewModel(),
            newsViewModel: NewsViewModel()
        )
    }
}
