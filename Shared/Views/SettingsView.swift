//
//  SettingsView.swift
//  RSS RAIder
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @ObservedObject var smartTagsViewModel: SmartTagsViewModel

    @State private var showingOPML = false
    @State private var iCloudSyncEnabled = true
    @State private var openInAppBrowser = UserDefaults.standard.bool(forKey: "openInAppBrowser")
    @State private var feedbinUsername: String
    @State private var feedbinPassword: String
    @State private var feedbinAlertMessage = ""
    @State private var showingFeedbinAlert = false
    @State private var showingAddSmartFeed = false
    @AppStorage("feedSource") private var feedSourceRaw = FeedSource.rss.rawValue
    @AppStorage("refreshOnLaunch") private var refreshOnLaunch = true
    @AppStorage("deleteReadArticlesAfterDays") private var deleteReadArticlesAfterDays = 0

    init(newsViewModel: NewsViewModel, smartFoldersViewModel: SmartFoldersViewModel, smartFeedsViewModel: SmartFeedsViewModel, feedsViewModel: FeedsViewModel, smartTagsViewModel: SmartTagsViewModel) {
        self.newsViewModel = newsViewModel
        self.smartFoldersViewModel = smartFoldersViewModel
        self.smartFeedsViewModel = smartFeedsViewModel
        self.feedsViewModel = feedsViewModel
        self.smartTagsViewModel = smartTagsViewModel
        _iCloudSyncEnabled = State(initialValue: feedsViewModel.iCloudSyncEnabled)
        let creds = FeedbinService.shared.credentials
        _feedbinUsername = State(initialValue: creds?.username ?? "")
        _feedbinPassword = State(initialValue: creds?.password ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Proveedor")
                        Spacer()
                        Text("Apple Intelligence")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Disponible en iOS 18+ y macOS 15+")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Servicio de IA")
                } footer: {
                    Text("Apple Intelligence es el unico servicio de IA configurado para analizar noticias.")
                }

                // Reading Preferences
                Section {
                    Toggle(isOn: $openInAppBrowser) {
                        Label("Abrir en navegador interno", systemImage: "doc.text.magnifyingglass")
                    }
                    .onChange(of: openInAppBrowser) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "openInAppBrowser")
                    }

                    #if os(iOS)
                    NavigationLink {
                        AppIconSettingsView()
                    } label: {
                        Label("Icono de la app", systemImage: "app.badge")
                    }
                    #endif

                } header: {
                    Text("Lectura")
                } footer: {
                    Text("Cuando está activado, los artículos se abren en el navegador interno de la app. Cuando está desactivado, se abren en Safari o tu navegador predeterminado.")
                }

                Section {
                    Picker("Fuente de noticias", selection: $feedSourceRaw) {
                        ForEach(FeedSource.allCases) { source in
                            Text(source.displayName).tag(source.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let source = FeedSource(rawValue: feedSourceRaw) {
                        Text(source.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if feedSourceRaw == FeedSource.feedbin.rawValue && !FeedbinService.shared.hasCredentials {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Feedbin requiere credenciales para cargar noticias.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Origen de noticias")
                } footer: {
                    Text("Selecciona entre RSS directo o Feedbin. Puedes cambiarlo cuando quieras.")
                }

                Section {
                    TextField("Usuario o token", text: $feedbinUsername)
                        #if os(iOS)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        #endif

                    SecureField("Contrasena", text: $feedbinPassword)
                        #if os(iOS)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        #endif

                    Button("Guardar credenciales") {
                        FeedbinService.shared.updateCredentials(username: feedbinUsername, password: feedbinPassword)
                    }

                    Button("Probar conexion") {
                        Task {
                            await testFeedbinConnection()
                        }
                    }
                } header: {
                    Text("Feedbin")
                } footer: {
                    Text("Usa Feedbin para depurar feeds y comparar resultados.")
                }

                // iCloud Sync
                Section {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        Label("Sincronizar con iCloud", systemImage: "icloud")
                    }
                    .onChange(of: iCloudSyncEnabled) { _, newValue in
                        feedsViewModel.iCloudSyncEnabled = newValue
                        smartFoldersViewModel.iCloudSyncEnabled = newValue
                        smartFeedsViewModel.iCloudSyncEnabled = newValue
                        newsViewModel.iCloudSyncEnabled = newValue

                        if newValue {
                            feedsViewModel.syncFromCloud()
                            smartFoldersViewModel.syncFromCloud()
                            smartFeedsViewModel.syncFromCloud()
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

                Section {
                    Toggle(isOn: $refreshOnLaunch) {
                        Label("Actualizar al abrir", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Actualización")
                } footer: {
                    Text("Cuando está activado, la app refresca tus feeds al abrir. Si está desactivado, tendrás que actualizar manualmente.")
                }

                // Article Cleanup
                Section {
                    Picker("Eliminar artículos leídos", selection: $deleteReadArticlesAfterDays) {
                        Text("Nunca").tag(0)
                        Text("Después de 1 día").tag(1)
                        Text("Después de 3 días").tag(3)
                        Text("Después de 7 días").tag(7)
                        Text("Después de 14 días").tag(14)
                        Text("Después de 30 días").tag(30)
                    }
                } header: {
                    Text("Limpieza de artículos")
                } footer: {
                    Text("Los artículos marcados como leídos se eliminarán automáticamente después del tiempo especificado. Los favoritos nunca se eliminan.")
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

                // Smart Tags Management
                Section {
                    NavigationLink {
                        SmartTagsListView(
                            smartTagsViewModel: smartTagsViewModel,
                            newsViewModel: newsViewModel
                        )
                    } label: {
                        HStack {
                            Label("Gestionar Etiquetas", systemImage: "tag")
                            Spacer()
                            Text("\(smartTagsViewModel.smartTags.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Etiquetas Inteligentes")
                }

                // Smart Feeds Management
                Section {
                    NavigationLink {
                        ManageSmartFeedsView(
                            smartFeedsViewModel: smartFeedsViewModel,
                            feedsViewModel: feedsViewModel
                        )
                    } label: {
                        HStack {
                            Label("Gestionar Smart Feeds", systemImage: "sparkles")
                            Spacer()
                            Text("\(smartFeedsViewModel.regularSmartFeeds.count)")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        showingAddSmartFeed = true
                    } label: {
                        Label("Añadir Smart Feed", systemImage: "plus")
                    }
                } header: {
                    Text("Smart Feeds")
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
            .sheet(isPresented: $showingAddSmartFeed) {
                SmartFeedEditorView(
                    smartFeedsViewModel: smartFeedsViewModel,
                    feedsViewModel: feedsViewModel,
                    smartFeed: nil,
                    allowsEmptyFeeds: false
                )
            }
            .alert("Feedbin", isPresented: $showingFeedbinAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(feedbinAlertMessage)
            }
        }
    }

    private func testFeedbinConnection() async {
        do {
            let count = try await FeedbinService.shared.testConnection()
            feedbinAlertMessage = "Conexion correcta. Suscripciones: \(count)"
        } catch {
            feedbinAlertMessage = error.localizedDescription
        }
        showingFeedbinAlert = true
    }
}

struct ManageSmartFoldersView: View {
    @ObservedObject var smartFoldersViewModel: SmartFoldersViewModel
    @State private var showingAddFolder = false
    @State private var folderToEdit: SmartFolder?

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
                .contextMenu {
                    Button {
                        folderToEdit = folder
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                }
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
        .sheet(item: $folderToEdit) { folder in
            AddSmartFolderView(smartFoldersViewModel: smartFoldersViewModel, smartFolder: folder)
        }
    }
}

struct ManageSmartFeedsView: View {
    @ObservedObject var smartFeedsViewModel: SmartFeedsViewModel
    @ObservedObject var feedsViewModel: FeedsViewModel
    @State private var showingAddFeed = false
    @State private var feedToEdit: SmartFeed?

    var body: some View {
        List {
            ForEach(smartFeedsViewModel.regularSmartFeeds) { smartFeed in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle(isOn: Binding(
                            get: { smartFeed.isEnabled },
                            set: { _ in smartFeedsViewModel.toggleSmartFeed(id: smartFeed.id) }
                        )) {
                            HStack {
                                Image(systemName: smartFeed.iconSystemName)
                                    .foregroundColor(.accentColor)
                                Text(smartFeed.name)
                                    .font(.headline)
                            }
                        }
                    }

                    Text("\(smartFeed.feedIDs.isEmpty ? feedsViewModel.feeds.count : smartFeed.feedIDs.count) feeds incluidos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button {
                        feedToEdit = smartFeed
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        smartFeedsViewModel.deleteSmartFeed(id: smartFeed.id)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    smartFeedsViewModel.deleteSmartFeed(id: smartFeedsViewModel.regularSmartFeeds[index].id)
                }
            }
        }
        .navigationTitle("Smart Feeds")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFeed = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFeed) {
            SmartFeedEditorView(
                smartFeedsViewModel: smartFeedsViewModel,
                feedsViewModel: feedsViewModel,
                smartFeed: nil,
                allowsEmptyFeeds: false
            )
        }
        .sheet(item: $feedToEdit) { smartFeed in
            SmartFeedEditorView(
                smartFeedsViewModel: smartFeedsViewModel,
                feedsViewModel: feedsViewModel,
                smartFeed: smartFeed,
                allowsEmptyFeeds: smartFeed.kind == .favorites
            )
        }
    }
}

#Preview {
    SettingsView(
        newsViewModel: NewsViewModel(),
        smartFoldersViewModel: SmartFoldersViewModel(),
        smartFeedsViewModel: SmartFeedsViewModel(),
        feedsViewModel: FeedsViewModel(),
        smartTagsViewModel: SmartTagsViewModel()
    )
}

#if os(iOS)
private struct AppIconOption: Identifiable {
    let id: String
    let title: String
    let iconName: String?

    static let all: [AppIconOption] = [
        AppIconOption(id: "default", title: "Automático", iconName: nil),
        AppIconOption(id: "light", title: "Claro", iconName: "AppIconLight"),
        AppIconOption(id: "dark", title: "Oscuro", iconName: "AppIconDark")
    ]
}

struct AppIconSettingsView: View {
    @State private var currentIconName: String?
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        List {
            if !UIApplication.shared.supportsAlternateIcons {
                Section {
                    Text("Este dispositivo no admite iconos alternativos.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                ForEach(AppIconOption.all) { option in
                    Button {
                        setIcon(option)
                    } label: {
                        HStack {
                            Text(option.title)
                            Spacer()
                            if isSelected(option) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(!UIApplication.shared.supportsAlternateIcons)
                }
            } header: {
                Text("Selecciona un icono")
            } footer: {
                Text("Los iconos claros y oscuros se pueden ajustar aquí.")
            }
        }
        .navigationTitle("Icono de la app")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            currentIconName = UIApplication.shared.alternateIconName
        }
        .alert("Icono de la app", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func isSelected(_ option: AppIconOption) -> Bool {
        if option.iconName == nil {
            return currentIconName == nil
        }
        return currentIconName == option.iconName
    }

    private func setIcon(_ option: AppIconOption) {
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            if let error = error {
                alertMessage = "No se pudo cambiar el icono: \(error.localizedDescription)"
                showAlert = true
            } else {
                currentIconName = option.iconName
            }
        }
    }
}
#endif
