//
//  RSSParser.swift
//  RSS RAIder
//

import Foundation

class RSSParser: NSObject {
    
    static func parse(data: Data, feedID: UUID, feedName: String) -> [NewsItem] {
        let parser = RSSParser(data: data, feedID: feedID, feedName: feedName)
        return parser.parse()
    }
    
    private let data: Data
    private let feedID: UUID
    private let feedName: String
    private var newsItems: [NewsItem] = []
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentSummary = ""
    private var currentPubDate: Date?
    private var isAtomFeed = false
    
    private init(data: Data, feedID: UUID, feedName: String) {
        self.data = data
        self.feedID = feedID
        self.feedName = feedName
    }
    
    private func parse() -> [NewsItem] {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()
        return newsItems
    }
    
    private func generateID(title: String) -> String {
        let hash = title.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
            .prefix(30)
        return "\(hash)-\(feedID.uuidString.prefix(8))-\(UUID().uuidString.prefix(8))"
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 first
        let iso8601 = ISO8601DateFormatter()
        if let date = iso8601.date(from: dateString) {
            return date
        }

        // Try standard date formatters
        let formatters: [DateFormatter] = [
            {
                let df = DateFormatter()
                df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                df.locale = Locale(identifier: "en_US_POSIX")
                return df
            }(),
            {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                df.locale = Locale(identifier: "en_US_POSIX")
                return df
            }(),
            {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                df.locale = Locale(identifier: "en_US_POSIX")
                return df
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
    
    private func cleanHTML(_ string: String) -> String {
        var cleaned = string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func saveCurrentItem() {
        guard !currentTitle.isEmpty, !currentLink.isEmpty else { return }
        
        let newsItem = NewsItem(
            id: generateID(title: currentTitle),
            title: cleanHTML(currentTitle),
            summary: cleanHTML(currentSummary),
            link: currentLink,
            pubDate: currentPubDate,
            feedID: feedID,
            feedName: feedName,
            qualityScore: nil,
            duplicateGroupID: nil,
            smartFolderIDs: []
        )
        
        newsItems.append(newsItem)
        
        currentTitle = ""
        currentLink = ""
        currentSummary = ""
        currentPubDate = nil
    }
}

extension RSSParser: XMLParserDelegate {
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        
        if elementName == "feed" {
            isAtomFeed = true
        }
        
        if isAtomFeed && elementName == "link" {
            if let href = attributeDict["href"], !href.isEmpty {
                currentLink = href
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "link" where !isAtomFeed:
            currentLink += trimmed
        case "description", "summary", "content":
            currentSummary += trimmed
        case "pubDate", "published", "updated":
            if let date = parseDate(trimmed) {
                currentPubDate = date
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch currentElement {
            case "title":
                currentTitle += trimmed
            case "description", "summary", "content":
                currentSummary += trimmed
            default:
                break
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            saveCurrentItem()
        }
        currentElement = ""
    }
}
