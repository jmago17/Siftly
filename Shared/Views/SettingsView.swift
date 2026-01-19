//
//  SettingsView.swift
//  RSS RAIder
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel

    @State private var claudeKey: String
    @State private var openAIKey: String
    @State private var selectedProvider: AIProvider
    @State private var showingManageFolders = false
    @State private var showingOPML = false
    @State private var iCloudSyncEnabled = true
    @State private var openInAppBrowser = UserDefaults.standard.bool(forKey: "openInAppBrowser")

    init(newsViewModel: NewsViewModel, smartFoldersViewModel: SmartFoldersViewModel, feedsViewModel: FeedsViewModel) {
        self.newsViewModel = newsViewModel
        self.smartFoldersViewModel = smartFoldersViewModel
        self.feedsViewModel = feedsViewModel
        _claudeKey = State(initialValue: newsViewModel.claudeAPIKey)
        _openAIKey = State(initialValue: newsViewModel.openAIAPIKey)
        _selectedProvider = State(initialValue: newsViewModel.selectedProvider)
        _iCloudSyncEnabled = State(initialValue: feedsViewModel.iCloudSyncEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                // AI Provider Section
                Section {
                    Picker("Proveedor de IA", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: selectedProvider) { _, newValue in
                        newsViewModel.updateProvider(newValue)
                    }

                    if selectedProvider == .appleIntelligence {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Disponible en iOS 18+ y macOS 15+")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Servicio de IA")
                } footer: {
                    Text("Selecciona el servicio de IA para analizar y clasificar noticias")
                }

                // API Keys Section
                if selectedProvider.requiresAPIKey {
                    Section {
                        if selectedProvider == .claude {
                            SecureField("Claude API Key", text: $claudeKey)
                                #if os(iOS)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                #endif
                                .onChange(of: claudeKey) { _, newValue in
                                    newsViewModel.updateAPIKeys(claude: newValue, openAI: openAIKey)
                                }

                            Link("Obtener API Key de Claude", destination: URL(string: "https://console.anthropic.com/")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }

                        if selectedProvider == .openAI {
                            SecureField("OpenAI API Key", text: $openAIKey)
                                #if os(iOS)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                #endif
                                .onChange(of: openAIKey) { _, newValue in
                                    newsViewModel.updateAPIKeys(claude: claudeKey, openAI: newValue)
                                }

                            Link("Obtener API Key de OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    } header: {
                        Text("API Key")
                    } footer: {
                        Text("Tu API key se almacena de forma segura en el dispositivo")
                    }
                }

                // Reading Preferences
                Section {
                    Toggle(isOn: $openInAppBrowser) {
                        Label("Abrir en navegador interno", systemImage: "doc.text.magnifyingglass")
                    }
                    .onChange(of: openInAppBrowser) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "openInAppBrowser")
                    }
                } header: {
                    Text("Lectura")
                } footer: {
                    Text("Cuando está activado, los artículos se abren en el navegador interno de la app. Cuando está desactivado, se abren en Safari o tu navegador predeterminado.")
                }

                // iCloud Sync
                Section {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        Label("Sincronizar con iCloud", systemImage: "icloud")
                    }
                    .onChange(of: iCloudSyncEnabled) { _, newValue in
                        feedsViewModel.iCloudSyncEnabled = newValue
                        smartFoldersViewModel.iCloudSyncEnabled = newValue

                        if newValue {
                            feedsViewModel.syncFromCloud()
                            smartFoldersViewModel.syncFromCloud()
                        }
                    }

                    if iCloudSyncEnabled, let lastSync = CloudSyncService.shared.lastSyncDate {
                        HStack {
                            Text("Última sincronización")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(lastSync, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Sincronización")
                } footer: {
                    Text("Sincroniza tus feeds y carpetas inteligentes entre todos tus dispositivos")
                }

                // OPML Import/Export
                Section {
                    Button {
                        showingOPML = true
                    } label: {
                        Label("Importar/Exportar OPML", systemImage: "doc.badge.arrow.up")
                    }
                } header: {
                    Text("Feeds")
                } footer: {
                    Text("Exporta tus feeds a formato OPML o importa feeds desde otros lectores RSS")
                }

                // Smart Folders Management
                Section {
                    NavigationLink {
                        ManageSmartFoldersView(smartFoldersViewModel: smartFoldersViewModel)
                    } label: {
                        HStack {
                            Label("Gestionar Carpetas", systemImage: "folder")
                            Spacer()
                            Text("\(smartFoldersViewModel.smartFolders.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Carpetas Inteligentes")
                }

                // About Section
                Section {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Acerca de")
                }
            }
            .navigationTitle("Configuración")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .sheet(isPresented: $showingOPML) {
                OPMLImportExportView(feedsViewModel: feedsViewModel)
            }
        }
    }
}

struct ManageSmartFoldersView: View {
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @State private var showingAddFolder = false

    var body: some View {
        List {
            ForEach(smartFoldersViewModel.smartFolders) { folder in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle(isOn: Binding(
                            get: { folder.isEnabled },
                            set: { _ in smartFoldersViewModel.toggleFolder(id: folder.id) }
                        )) {
                            Text(folder.name)
                                .font(.headline)
                        }
                    }

                    Text(folder.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    if folder.matchCount > 0 {
                        Text("\(folder.matchCount) artículos")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    smartFoldersViewModel.deleteFolder(id: smartFoldersViewModel.smartFolders[index].id)
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
    }
}

#Preview {
    SettingsView(
        newsViewModel: NewsViewModel(),
        smartFoldersViewModel: SmartFoldersViewModel(),
        feedsViewModel: FeedsViewModel()
    )
}
