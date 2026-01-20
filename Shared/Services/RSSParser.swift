//
//  RSSParser.swift
//  RSS RAIder
//

import Foundation
import CryptoKit

class RSSParser: NSObject {

    static func parse(data: Data, feedID: UUID, feedName: String, feedURL: URL? = nil) -> [NewsItem] {
        let parser = RSSParser(data: data, feedID: feedID, feedName: feedName, feedURL: feedURL)
        return parser.parse()
    }
    
    private let data: Data
    private let feedID: UUID
    private let feedName: String
    private let feedURL: URL?
    private var newsItems: [NewsItem] = []
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentLinkCandidates: [String] = []
    private var currentSummary = ""
    private var currentContent = ""
    private var currentPubDate: Date?
    private var currentAuthor = ""
    private var currentGuid = ""
    private var currentGuidIsPermaLink = false
    private var currentID = ""
    private var currentImageCandidates: [String] = []
    private var isAtomFeed = false
    private var isInsideItem = false
    private var isInsideAuthor = false
    
    private init(data: Data, feedID: UUID, feedName: String, feedURL: URL?) {
        self.data = data
        self.feedID = feedID
        self.feedName = feedName
        self.feedURL = feedURL
    }
    
    private func parse() -> [NewsItem] {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()
        return newsItems
    }
    
    private func generateID(title: String, link: String) -> String {
        // Generate deterministic ID using a stable hash
        let combined = "\(title)|\(link)".lowercased()
        let digest = SHA256.hash(data: Data(combined.utf8))
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        return "\(feedID.uuidString.prefix(8))-\(hashString.prefix(12))"
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
        // Use the comprehensive text cleaner for better results
        var cleaned = TextCleaner.cleanForSummarization(string)

        // Additional cleanup for feed-specific content
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    private func resetCurrentItem() {
        currentTitle = ""
        currentLink = ""
        currentLinkCandidates = []
        currentSummary = ""
        currentContent = ""
        currentPubDate = nil
        currentAuthor = ""
        currentGuid = ""
        currentGuidIsPermaLink = false
        currentID = ""
        currentImageCandidates = []
        isInsideAuthor = false
    }

    private func resolveLink(_ link: String) -> String? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url.absoluteString
        }

        if let base = feedURL, let resolved = URL(string: trimmed, relativeTo: base) {
            return resolved.absoluteURL.absoluteString
        }

        return trimmed
    }

    private func normalizeLinkText(_ text: String) -> String {
        var normalized = text.replacingOccurrences(of: "https//", with: "https://")
        normalized = normalized.replacingOccurrences(of: "http//", with: "http://")
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractURLCandidates(from text: String) -> [String] {
        let schemePattern = #"https?://"#
        let urlPattern = #"https?://[^\s"'<>]+"#
        guard let schemeRegex = try? NSRegularExpression(pattern: schemePattern, options: [.caseInsensitive]),
              let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: [.caseInsensitive]) else {
            return []
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let schemeMatches = schemeRegex.matches(in: text, options: [], range: fullRange)
        guard !schemeMatches.isEmpty else { return [] }

        var results: [String] = []

        for (index, match) in schemeMatches.enumerated() {
            let start = match.range.location
            let end: Int
            if index + 1 < schemeMatches.count {
                end = schemeMatches[index + 1].range.location
            } else {
                end = fullRange.location + fullRange.length
            }

            let candidateRange = NSRange(location: start, length: max(0, end - start))
            guard let range = Range(candidateRange, in: text) else { continue }
            let candidate = String(text[range])
            let candidateRangeFull = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
            if let urlMatch = urlRegex.firstMatch(in: candidate, options: [], range: candidateRangeFull),
               let urlRange = Range(urlMatch.range, in: candidate) {
                results.append(String(candidate[urlRange]))
            }
        }

        return results
    }

    private func cleanedCandidate(_ candidate: String) -> String {
        candidate.trimmingCharacters(in: CharacterSet(charactersIn: ".,);]}>"))
    }

    private func selectBestURL(from rawCandidates: [String]) -> String? {
        var resolvedCandidates: [String] = []

        for raw in rawCandidates {
            let normalized = normalizeLinkText(raw)
            guard !normalized.isEmpty else { continue }
            let extracted = extractURLCandidates(from: normalized)
            if extracted.isEmpty {
                if let resolved = resolveLink(normalized) {
                    resolvedCandidates.append(resolved)
                }
            } else {
                for item in extracted {
                    if let resolved = resolveLink(item) {
                        resolvedCandidates.append(resolved)
                    }
                }
            }
        }

        let uniqueCandidates = Array(Set(resolvedCandidates)).map(cleanedCandidate)
        guard !uniqueCandidates.isEmpty else { return nil }

        let imageExtensions = Set(["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "tiff"])

        func score(_ urlString: String) -> (Int, Int) {
            guard let url = URL(string: urlString), let host = url.host, !host.isEmpty else {
                return (-1000, urlString.count)
            }

            var value = 0
            if !url.path.isEmpty && url.path != "/" {
                value += 6
            }

            if let ext = url.path.split(separator: ".").last?.lowercased(), imageExtensions.contains(String(ext)) {
                value -= 6
            } else {
                value += 4
            }

            if url.query?.isEmpty == false {
                value += 1
            }

            return (value, urlString.count)
        }

        return uniqueCandidates.max { lhs, rhs in
            let lhsScore = score(lhs)
            let rhsScore = score(rhs)
            if lhsScore.0 != rhsScore.0 {
                return lhsScore.0 < rhsScore.0
            }
            return lhsScore.1 < rhsScore.1
        }
    }

    private func registerImageCandidate(_ raw: String, typeHint: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard isImageCandidate(trimmed, typeHint: typeHint) else { return }

        let normalized = normalizeLinkText(trimmed)
        let resolved = resolveLink(normalized) ?? normalized
        let cleaned = cleanedCandidate(resolved)

        if !currentImageCandidates.contains(cleaned) {
            currentImageCandidates.append(cleaned)
        }
    }

    private func selectBestImageURL(from rawCandidates: [String]) -> String? {
        guard !rawCandidates.isEmpty else { return nil }

        let unique = Array(Set(rawCandidates))
        if unique.count == 1 {
            return unique[0]
        }

        let imageExtensions = Set(["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "tiff"])
        func score(_ urlString: String) -> (Int, Int) {
            guard let url = URL(string: urlString) else { return (-1000, urlString.count) }
            var value = 0
            if let ext = url.path.split(separator: ".").last?.lowercased(), imageExtensions.contains(String(ext)) {
                value += 2
            }
            if url.query?.isEmpty == false {
                value += 1
            }
            return (value, urlString.count)
        }

        return unique.max { lhs, rhs in
            let lhsScore = score(lhs)
            let rhsScore = score(rhs)
            if lhsScore.0 != rhsScore.0 {
                return lhsScore.0 < rhsScore.0
            }
            return lhsScore.1 < rhsScore.1
        }
    }

    private func isImageCandidate(_ urlString: String, typeHint: String?) -> Bool {
        if let typeHint = typeHint, typeHint.contains("image") {
            return true
        }

        guard let url = URL(string: urlString) else { return false }
        let path = url.path.lowercased()
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "tiff"]
        return imageExtensions.contains { path.hasSuffix(".\($0)") }
    }

    private func saveCurrentItem() {
        var candidates = currentLinkCandidates
        if !currentLink.isEmpty {
            candidates.append(currentLink)
        }
        if currentGuidIsPermaLink {
            candidates.append(currentGuid)
        }
        candidates.append(currentID)

        let resolvedLink = selectBestURL(from: candidates)

        guard let finalLink = resolvedLink else {
            resetCurrentItem()
            return
        }

        let title = currentTitle.isEmpty ? "Sin titulo" : currentTitle
        let summarySource = currentContent.count > currentSummary.count ? currentContent : currentSummary

        let newsItem = NewsItem(
            id: generateID(title: title, link: finalLink),
            title: cleanHTML(title),
            summary: cleanHTML(summarySource),
            link: finalLink,
            pubDate: currentPubDate,
            feedID: feedID,
            feedName: feedName,
            imageURL: selectBestImageURL(from: currentImageCandidates),
            author: currentAuthor.isEmpty ? nil : cleanHTML(currentAuthor),
            rawSummary: summarySource.isEmpty ? nil : summarySource,
            rawContent: currentContent.isEmpty ? nil : currentContent,
            cleanTitle: nil,
            cleanBody: nil,
            qualityScore: nil,
            duplicateGroupID: nil,
            smartFolderIDs: []
        )

        newsItems.append(newsItem)

        resetCurrentItem()
    }
}

extension RSSParser: XMLParserDelegate {
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let normalizedElement = elementName.lowercased()
        currentElement = normalizedElement

        if normalizedElement == "feed" {
            isAtomFeed = true
        }

        if normalizedElement == "item" || normalizedElement == "entry" {
            isInsideItem = true
            resetCurrentItem()
        }

        if normalizedElement == "guid" {
            let lowercasedAttributes = Dictionary(uniqueKeysWithValues: attributeDict.map { ($0.key.lowercased(), $0.value) })
            let isPermaLinkValue = lowercasedAttributes["ispermalink"]?.lowercased()
            currentGuidIsPermaLink = isPermaLinkValue == nil || isPermaLinkValue == "true"
        }

        if normalizedElement == "author" && isInsideItem {
            isInsideAuthor = true
        }

        if isAtomFeed && normalizedElement == "link" && isInsideItem {
            let rel = attributeDict["rel"]?.lowercased()
            let type = attributeDict["type"]?.lowercased()
            let isAlternate = rel == nil || rel == "alternate"
            let isHTML = type == nil || type == "text/html" || type == "application/xhtml+xml"
            if isAlternate && isHTML, let href = attributeDict["href"], !href.isEmpty {
                if !currentLinkCandidates.contains(href) {
                    currentLinkCandidates.append(href)
                }
            }

            if rel == "enclosure", let href = attributeDict["href"] {
                registerImageCandidate(href, typeHint: type)
            }
        }

        guard isInsideItem else { return }

        if normalizedElement == "enclosure" {
            if let url = attributeDict["url"] {
                let typeHint = attributeDict["type"]?.lowercased() ?? attributeDict["medium"]?.lowercased()
                registerImageCandidate(url, typeHint: typeHint)
            }
        }

        if normalizedElement == "media:content"
            || normalizedElement == "media:thumbnail"
            || normalizedElement == "itunes:image"
            || normalizedElement == "image"
            || normalizedElement == "thumbnail" {
            let url = attributeDict["url"] ?? attributeDict["href"]
            if let url = url {
                let typeHint = attributeDict["type"]?.lowercased() ?? attributeDict["medium"]?.lowercased()
                registerImageCandidate(url, typeHint: typeHint)
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard isInsideItem else { return }

        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "link" where !isAtomFeed:
            currentLink += trimmed
        case "description", "summary", "content", "content:encoded", "encoded":
            currentSummary += trimmed
            if currentElement == "content:encoded" || currentElement == "encoded" {
                currentContent += trimmed
            }
        case "author", "dc:creator", "creator":
            currentAuthor += trimmed
        case "name" where isInsideAuthor:
            currentAuthor += trimmed
        case "pubDate", "published", "updated":
            if let date = parseDate(trimmed) {
                currentPubDate = date
            }
        case "guid":
            currentGuid += trimmed
        case "id":
            currentID += trimmed
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

            guard isInsideItem else { return }

            switch currentElement {
            case "title":
                currentTitle += trimmed
            case "description", "summary", "content", "content:encoded", "encoded":
                currentSummary += trimmed
                if currentElement == "content:encoded" || currentElement == "encoded" {
                    currentContent += trimmed
                }
            case "author", "dc:creator", "creator":
                currentAuthor += trimmed
            case "name" where isInsideAuthor:
                currentAuthor += trimmed
            default:
                break
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let normalizedElement = elementName.lowercased()
        if normalizedElement == "item" || normalizedElement == "entry" {
            saveCurrentItem()
            isInsideItem = false
            isInsideAuthor = false
        } else if normalizedElement == "link" && isInsideItem && !isAtomFeed {
            if !currentLink.isEmpty {
                currentLinkCandidates.append(currentLink)
                currentLink = ""
            }
        } else if normalizedElement == "author" && isInsideItem {
            isInsideAuthor = false
        }
        currentElement = ""
    }
}
