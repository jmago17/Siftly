import WidgetKit
import SwiftUI
import AppIntents

private enum WidgetConstants {
    static let appGroupID = "group.com.rssraider.app"
    static let feedsKey = "widget_feeds"
    static let foldersKey = "widget_folders"
    static let smartFeedsKey = "widget_smartfeeds"
    static let articlesKey = "widget_articles"
}

struct WidgetFeed: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: String
}

struct WidgetFolder: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let feedIDs: [UUID]
}

struct WidgetSmartFeed: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let feedIDs: [UUID]
}

struct WidgetArticle: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let feedID: UUID
    let feedName: String
    let link: String
    let pubDate: Date?
    let qualityScore: Int?
}

enum WidgetDataStore {
    static func loadFeeds() -> [WidgetFeed] {
        decodeArray(WidgetFeed.self, key: WidgetConstants.feedsKey)
    }

    static func loadFolders() -> [WidgetFolder] {
        decodeArray(WidgetFolder.self, key: WidgetConstants.foldersKey)
    }

    static func loadSmartFeeds() -> [WidgetSmartFeed] {
        decodeArray(WidgetSmartFeed.self, key: WidgetConstants.smartFeedsKey)
    }

    static func loadArticles() -> [WidgetArticle] {
        decodeArray(WidgetArticle.self, key: WidgetConstants.articlesKey)
    }

    private static func decodeArray<T: Decodable>(_ type: T.Type, key: String) -> [T] {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupID),
              let data = defaults.data(forKey: key) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([T].self, from: data)) ?? []
    }
}

enum WidgetSourceKind: String, AppEnum {
    case hot
    case smartFeed
    case folder
    case feed

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Fuente")
    }

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .hot: DisplayRepresentation(title: "Hot News"),
            .smartFeed: DisplayRepresentation(title: "Smart Feed"),
            .folder: DisplayRepresentation(title: "Carpeta"),
            .feed: DisplayRepresentation(title: "Feed")
        ]
    }
}

struct WidgetSourceEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Fuente")
    }

    static var defaultQuery = WidgetSourceQuery()

    let id: String
    let name: String
    let kind: WidgetSourceKind

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: kind.displayName)
        )
    }

    static var hot: WidgetSourceEntity {
        WidgetSourceEntity(id: "hot", name: "Hot News", kind: .hot)
    }
}

struct WidgetSourceQuery: EntityQuery {
    func suggestedEntities() async -> [WidgetSourceEntity] {
        var entities: [WidgetSourceEntity] = [.hot]

        let smartFeeds = WidgetDataStore.loadSmartFeeds().map {
            WidgetSourceEntity(id: "smart:\($0.id.uuidString)", name: $0.name, kind: .smartFeed)
        }
        let folders = WidgetDataStore.loadFolders().map {
            WidgetSourceEntity(id: "folder:\($0.id.uuidString)", name: $0.name, kind: .folder)
        }
        let feeds = WidgetDataStore.loadFeeds().map {
            WidgetSourceEntity(id: "feed:\($0.id.uuidString)", name: $0.name, kind: .feed)
        }

        entities.append(contentsOf: smartFeeds)
        entities.append(contentsOf: folders)
        entities.append(contentsOf: feeds)
        return entities
    }

    func entities(for identifiers: [WidgetSourceEntity.ID]) async -> [WidgetSourceEntity] {
        let lookup = await suggestedEntities()
        let set = Set(identifiers)
        return lookup.filter { set.contains($0.id) }
    }
}

struct ArticleSourceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Fuente"
    static var description = IntentDescription("Elige la fuente de noticias para el widget")

    @Parameter(title: "Fuente", default: .hot)
    var source: WidgetSourceEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Mostrar") {
            \.$source
        }
    }

    init() { }
}

private extension WidgetSourceKind {
    var displayName: String {
        switch self {
        case .hot:
            return "Hot News"
        case .smartFeed:
            return "Smart Feed"
        case .folder:
            return "Carpeta"
        case .feed:
            return "Feed"
        }
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ArticleSourceIntent
    let title: String
    let articles: [WidgetArticle]
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: ArticleSourceIntent(), title: "Hot News", articles: sampleArticles())
    }

    func snapshot(for configuration: ArticleSourceIntent, in context: Context) async -> WidgetEntry {
        buildEntry(for: configuration)
    }

    func timeline(for configuration: ArticleSourceIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let entry = buildEntry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func buildEntry(for configuration: ArticleSourceIntent) -> WidgetEntry {
        let data = WidgetContentBuilder(configuration: configuration)
        return WidgetEntry(date: Date(), configuration: configuration, title: data.title, articles: data.articles)
    }
}

private struct WidgetContentBuilder {
    let title: String
    let articles: [WidgetArticle]

    init(configuration: ArticleSourceIntent) {
        let source = configuration.source ?? .hot
        let allArticles = WidgetDataStore.loadArticles()
        let feeds = WidgetDataStore.loadFeeds()
        let folders = WidgetDataStore.loadFolders()
        let smartFeeds = WidgetDataStore.loadSmartFeeds()

        switch source.kind {
        case .hot:
            title = "Hot News"
            articles = Self.hotArticles(from: allArticles)
        case .feed:
            if let feedID = Self.parseUUID(from: source.id),
               let feed = feeds.first(where: { $0.id == feedID }) {
                title = feed.name
                articles = Self.filteredArticles(allArticles, feedIDs: [feedID])
            } else {
                title = "Hot News"
                articles = Self.hotArticles(from: allArticles)
            }
        case .folder:
            if let folderID = Self.parseUUID(from: source.id),
               let folder = folders.first(where: { $0.id == folderID }) {
                title = folder.name
                articles = Self.filteredArticles(allArticles, feedIDs: folder.feedIDs)
            } else {
                title = "Hot News"
                articles = Self.hotArticles(from: allArticles)
            }
        case .smartFeed:
            if let smartID = Self.parseUUID(from: source.id),
               let smart = smartFeeds.first(where: { $0.id == smartID }) {
                title = smart.name
                articles = Self.filteredArticles(allArticles, feedIDs: smart.feedIDs)
            } else {
                title = "Hot News"
                articles = Self.hotArticles(from: allArticles)
            }
        }
    }

    private static func parseUUID(from id: String) -> UUID? {
        let parts = id.split(separator: ":")
        guard let last = parts.last else { return nil }
        return UUID(uuidString: String(last))
    }

    private static func filteredArticles(_ articles: [WidgetArticle], feedIDs: [UUID]) -> [WidgetArticle] {
        guard !feedIDs.isEmpty else { return hotArticles(from: articles) }
        return articles
            .filter { feedIDs.contains($0.feedID) }
            .sorted(by: articleSort)
    }

    private static func hotArticles(from articles: [WidgetArticle]) -> [WidgetArticle] {
        let scored = articles.sorted { lhs, rhs in
            let lScore = lhs.qualityScore ?? 0
            let rScore = rhs.qualityScore ?? 0
            if lScore != rScore { return lScore > rScore }
            return articleSort(lhs, rhs)
        }
        return scored
    }

    private static func articleSort(_ lhs: WidgetArticle, _ rhs: WidgetArticle) -> Bool {
        switch (lhs.pubDate, rhs.pubDate) {
        case let (l?, r?):
            return l > r
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.title < rhs.title
        }
    }
}

struct CremaWidget: Widget {
    let kind: String = "CremaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ArticleSourceIntent.self, provider: Provider()) { entry in
            CremaWidgetView(entry: entry)
        }
        .configurationDisplayName("Crema")
        .description("Noticias destacadas de tus fuentes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CremaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    private var maxItems: Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 2
        case .systemLarge:
            return 4
        default:
            return 2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.headline)
                .lineLimit(1)

            if entry.articles.isEmpty {
                Text("Sin noticias")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.articles.prefix(maxItems)) { article in
                    ArticleRow(article: article)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .widgetBackground()
    }
}

struct ArticleRow: View {
    let article: WidgetArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(article.title)
                .font(.subheadline)
                .lineLimit(2)

            Text(article.feedName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

private extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self
        }
    }
}

@main
struct CremaWidgets: WidgetBundle {
    var body: some Widget {
        CremaWidget()
    }
}

private func sampleArticles() -> [WidgetArticle] {
    [
        WidgetArticle(id: "1", title: "Titular destacado para el widget", feedID: UUID(), feedName: "Crema", link: "https://example.com", pubDate: Date(), qualityScore: 92),
        WidgetArticle(id: "2", title: "Otra noticia interesante para tu resumen", feedID: UUID(), feedName: "Tech Feed", link: "https://example.com", pubDate: Date().addingTimeInterval(-3600), qualityScore: 80),
        WidgetArticle(id: "3", title: "Actualización rápida del día", feedID: UUID(), feedName: "Noticias", link: "https://example.com", pubDate: Date().addingTimeInterval(-7200), qualityScore: 76),
        WidgetArticle(id: "4", title: "Resumen breve para el modo grande", feedID: UUID(), feedName: "Economía", link: "https://example.com", pubDate: Date().addingTimeInterval(-10800), qualityScore: 70)
    ]
}
