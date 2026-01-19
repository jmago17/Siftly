//
//  OPMLService.swift
//  RSS RAIder
//

import Foundation

/// Service for importing and exporting feeds in OPML format
class OPMLService {

    // MARK: - Export

    /// Export feeds to OPML format
    static func exportToOPML(feeds: [RSSFeed]) -> String {
        var opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>RSSFilter Feed List</title>
                <dateCreated>\(dateFormatter.string(from: Date()))</dateCreated>
            </head>
            <body>

        """

        for feed in feeds {
            let escapedName = feed.name.xmlEscaped
            let escapedURL = feed.url.xmlEscaped

            opml += """
                    <outline text="\(escapedName)" title="\(escapedName)" type="rss" xmlUrl="\(escapedURL)" />

            """
        }

        opml += """
            </body>
        </opml>
        """

        return opml
    }

    /// Save OPML to file
    static func saveOPMLToFile(feeds: [RSSFeed]) -> URL? {
        let opml = exportToOPML(feeds: feeds)

        let fileName = "rssfilter-feeds-\(dateFileFormatter.string(from: Date())).opml"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try opml.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving OPML: \(error)")
            return nil
        }
    }

    // MARK: - Import

    /// Import feeds from OPML data
    static func importFromOPML(data: Data) -> [RSSFeed] {
        let parser = OPMLParser(data: data)
        return parser.parse()
    }

    /// Import feeds from OPML file URL
    static func importFromOPMLFile(url: URL) -> [RSSFeed] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        return importFromOPML(data: data)
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dateFileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

// MARK: - OPML Parser

private class OPMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var feeds: [RSSFeed] = []
    private var currentElement = ""
    private var currentAttributes: [String: String] = [:]

    init(data: Data) {
        self.data = data
    }

    func parse() -> [RSSFeed] {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()
        return feeds
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict

        if elementName == "outline" {
            // Check if it's a feed outline (has xmlUrl)
            if let xmlUrl = attributeDict["xmlUrl"], !xmlUrl.isEmpty {
                let name = attributeDict["title"] ?? attributeDict["text"] ?? "Untitled Feed"
                let feed = RSSFeed(name: name, url: xmlUrl)
                feeds.append(feed)
            }
        }
    }
}

// MARK: - String XML Escaping

private extension String {
    var xmlEscaped: String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
