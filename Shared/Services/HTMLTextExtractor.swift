//
//  HTMLTextExtractor.swift
//  RSS RAIder
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

class HTMLTextExtractor {
    static let shared = HTMLTextExtractor()

    private init() {}

    /// Extract readable text from a URL
    func extractText(from url: String) async throws -> ArticleContent {
        guard let articleURL = URL(string: url) else {
            throw ExtractionError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: articleURL)

        let html = decodeHTML(data) ?? String(decoding: data, as: UTF8.self)

        return parseHTML(html, url: articleURL)
    }

    private func parseHTML(_ html: String, url: URL) -> ArticleContent {
        let metaTags = extractMetaTags(from: html)

        let imageURL = extractMetaContent(from: metaTags, keys: [
            "og:image", "og:image:url", "twitter:image", "twitter:image:src"
        ])
        let author = extractMetaContent(from: metaTags, keys: [
            "author", "article:author", "twitter:creator", "byline", "byl", "dc.creator"
        ])

        let extracted = ArticleTextExtractor.shared.extract(from: html, url: url, rssTitle: nil)
        let cleanTitle = extracted.title.isEmpty ? "Articulo" : extracted.title

        return ArticleContent(
            title: cleanTitle,
            text: extracted.body,
            url: url.absoluteString,
            imageURL: resolveRelativeURL(imageURL, base: url.absoluteString),
            author: normalizeAuthor(author)
        )
    }

    private func resolveRelativeURL(_ link: String?, base: String) -> String? {
        guard let link = link?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else {
            return nil
        }

        if let url = URL(string: link), url.scheme != nil {
            return url.absoluteString
        }

        if let baseURL = URL(string: base), let resolved = URL(string: link, relativeTo: baseURL) {
            return resolved.absoluteURL.absoluteString
        }

        return link
    }

    private func extractMetaTags(from html: String) -> [[String: String]] {
        let pattern = "<meta\\s+[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))

        return matches.compactMap { match in
            let tag = nsString.substring(with: match.range)
            let attributes = parseAttributes(from: tag)
            return attributes.isEmpty ? nil : attributes
        }
    }

    private func parseAttributes(from tag: String) -> [String: String] {
        let pattern = "([a-zA-Z0-9_:\\-]+)\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [:]
        }

        let nsString = tag as NSString
        let matches = regex.matches(in: tag, options: [], range: NSRange(location: 0, length: nsString.length))

        var attributes: [String: String] = [:]
        for match in matches {
            if match.numberOfRanges >= 3 {
                let key = nsString.substring(with: match.range(at: 1)).lowercased()
                let value = nsString.substring(with: match.range(at: 2))
                attributes[key] = value
            }
        }

        return attributes
    }

    private func extractMetaContent(from metaTags: [[String: String]], keys: [String]) -> String? {
        let targetKeys = Set(keys.map { $0.lowercased() })
        for tag in metaTags {
            let name = tag["name"]?.lowercased()
            let property = tag["property"]?.lowercased()
            if let candidate = name, targetKeys.contains(candidate) {
                return tag["content"]
            }
            if let candidate = property, targetKeys.contains(candidate) {
                return tag["content"]
            }
        }
        return nil
    }

    private func normalizeAuthor(_ author: String?) -> String? {
        guard let author = author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty else {
            return nil
        }

        if author.hasPrefix("@") {
            return String(author.dropFirst())
        }

        return author
    }

    private func decodeHTML(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }
        if let windows1252 = String(data: data, encoding: .windowsCP1252) {
            return windows1252
        }
        return nil
    }

    private func extractTitle(from html: String, metaTags: [[String: String]]? = nil) -> String {
        if let metaTags = metaTags,
           let metaTitle = extractMetaContent(from: metaTags, keys: ["og:title", "twitter:title"]),
           !metaTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return decodeHTMLEntities(metaTitle)
        }

        // Try to extract from <title> tag
        if let titleRange = html.range(of: "<title[^>]*>([^<]+)</title>", options: .regularExpression) {
            let titleHTML = String(html[titleRange])
            let title = stripHTMLTags(titleHTML)
            if !title.isEmpty {
                return decodeHTMLEntities(title)
            }
        }

        // Try to extract from <h1> tag
        if let h1Range = html.range(of: "<h1[^>]*>([^<]+)</h1>", options: .regularExpression) {
            let h1HTML = String(html[h1Range])
            let title = stripHTMLTags(h1HTML)
            if !title.isEmpty {
                return decodeHTMLEntities(title)
            }
        }

        return "Artículo"
    }

    private func extractMainContent(from html: String) -> String {
        let candidates = extractContentCandidates(from: html)
        if let best = selectBestCandidate(from: candidates) {
            return best
        }

        let paragraphs = extractParagraphs(from: html)
        return paragraphs.joined(separator: "\n\n")
    }

    private func extractParagraphs(from html: String) -> [String] {
        var paragraphs: [String] = []

        let pPattern = "<p[^>]*>(.*?)</p>"
        let regex = try? NSRegularExpression(pattern: pPattern, options: [.dotMatchesLineSeparators])
        let nsString = html as NSString
        let results = regex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))

        results?.forEach { match in
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                let paragraph = nsString.substring(with: range)
                let cleaned = stripHTMLTags(paragraph)
                let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count > 20 && !isBoilerplateParagraph(trimmed) {
                    paragraphs.append(decodeHTMLEntities(cleaned))
                }
            }
        }

        return paragraphs
    }

    private func extractContentCandidates(from html: String) -> [String] {
        let patterns: [(String, Int)] = [
            ("<article[^>]*>(.*?)</article>", 1),
            ("<main[^>]*>(.*?)</main>", 1),
            ("<section[^>]*class=['\\\"][^'\\\"]*(article|content|post|entry|story|body|text)[^'\\\"]*['\\\"][^>]*>(.*?)</section>", 2),
            ("<div[^>]*class=['\\\"][^'\\\"]*(article|content|post|entry|story|body|text)[^'\\\"]*['\\\"][^>]*>(.*?)</div>", 2),
            ("<div[^>]*id=['\\\"][^'\\\"]*(article|content|post|entry|story|body|text)[^'\\\"]*['\\\"][^>]*>(.*?)</div>", 2)
        ]

        var results: [String] = []
        for (pattern, captureIndex) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
                continue
            }

            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches where match.numberOfRanges > captureIndex {
                let range = match.range(at: captureIndex)
                let content = nsString.substring(with: range)
                if !content.isEmpty {
                    results.append(content)
                }
            }
        }

        return results
    }

    private func selectBestCandidate(from candidates: [String]) -> String? {
        var bestCandidate: String?
        var bestScore = 0

        for candidate in candidates {
            let score = scoreCandidate(candidate)
            if score > bestScore {
                bestScore = score
                bestCandidate = candidate
            }
        }

        if bestScore < 80 {
            return nil
        }

        return bestCandidate
    }

    private func scoreCandidate(_ html: String) -> Int {
        let text = cleanWhitespace(stripHTMLTags(html))
        let wordCount = text.split { $0.isWhitespace }.count
        let paragraphCount = text.components(separatedBy: "\n\n").count
        return wordCount + (paragraphCount * 20)
    }

    private func removeTagsAndContent(_ html: String, tag: String) -> String {
        let pattern = "<\(tag)[^>]*>.*?</\(tag)>"
        return html.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private func stripHTMLTags(_ html: String) -> String {
        var text = html

        // Add newlines for certain tags
        text = text.replacingOccurrences(of: "</p>", with: "</p>\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</h[1-6]>", with: "</h>\n\n", options: .regularExpression)

        // Remove all HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        return text
    }

    private func removeBoilerplate(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 20 {
                return false
            }
            return !isBoilerplateParagraph(trimmed)
        }

        return filtered.joined(separator: "\n")
    }

    private func isBoilerplateParagraph(_ text: String) -> Bool {
        let lower = text.lowercased()

        // Cookie/privacy related
        let privacyKeywords = [
            "cookies", "cookie", "privacidad", "privacy", "terminos", "terms",
            "aviso legal", "legal notice", "acept", "consent", "gdpr"
        ]
        if privacyKeywords.contains(where: { lower.contains($0) }) {
            return true
        }

        // Subscribe/newsletter related
        let subscribeKeywords = [
            "suscrib", "subscribe", "newsletter", "registrate", "sign up",
            "join our", "get updates", "recibe noticias"
        ]
        if subscribeKeywords.contains(where: { lower.contains($0) }) {
            return true
        }

        // Social share related
        let socialKeywords = [
            "share on", "compartir en", "share this", "comparte este",
            "follow us", "siguenos", "like us on", "tweet this"
        ]
        if socialKeywords.contains(where: { lower.contains($0) }) {
            return true
        }

        // Check for social network mentions in short text (likely share buttons)
        let socialNetworks = ["facebook", "twitter", "linkedin", "whatsapp", "telegram", "pinterest"]
        let wordCount = text.split { $0.isWhitespace }.count
        if wordCount <= 6 {
            let socialCount = socialNetworks.filter { lower.contains($0) }.count
            if socialCount >= 2 {
                return true
            }
        }

        // Ad/promo related
        let adKeywords = ["publicidad", "advertisement", "sponsored", "patrocinado", "promo"]
        if adKeywords.contains(where: { lower.contains($0) }) {
            return true
        }

        return false
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]

        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }

        // Decode numeric entities
        let numericPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if match.numberOfRanges > 1 {
                    let numberRange = match.range(at: 1)
                    let number = nsString.substring(with: numberRange)
                    if let code = Int(number), let scalar = UnicodeScalar(code) {
                        let char = String(scalar)
                        let fullRange = match.range
                        result = (result as NSString).replacingCharacters(in: fullRange, with: char)
                    }
                }
            }
        }

        return result
    }

    private func cleanWhitespace(_ text: String) -> String {
        var result = text

        // Replace multiple spaces with single space
        result = result.replacingOccurrences(of: " +", with: " ", options: .regularExpression)

        // Replace multiple newlines with double newline
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}

struct ArticleContent {
    let title: String
    let text: String
    let url: String
    let imageURL: String?
    let author: String?
}

enum ExtractionError: LocalizedError {
    case invalidURL
    case networkError
    case decodingFailed
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .networkError:
            return "Error de red al descargar el artículo"
        case .decodingFailed:
            return "Error al decodificar el contenido"
        case .parsingFailed:
            return "Error al extraer el texto del artículo"
        }
    }
}
