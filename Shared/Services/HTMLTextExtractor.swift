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

        guard let html = String(data: data, encoding: .utf8) else {
            throw ExtractionError.decodingFailed
        }

        return parseHTML(html, url: url)
    }

    private func parseHTML(_ html: String, url: String) -> ArticleContent {
        var text = html

        // Remove script and style tags
        text = removeTagsAndContent(text, tag: "script")
        text = removeTagsAndContent(text, tag: "style")
        text = removeTagsAndContent(text, tag: "nav")
        text = removeTagsAndContent(text, tag: "header")
        text = removeTagsAndContent(text, tag: "footer")

        // Extract title
        let title = extractTitle(from: html)

        // Try to find main content area
        let content = extractMainContent(from: text)

        // Clean up the text
        var cleanText = stripHTMLTags(content)
        cleanText = decodeHTMLEntities(cleanText)
        cleanText = cleanWhitespace(cleanText)

        return ArticleContent(
            title: title,
            text: cleanText,
            url: url
        )
    }

    private func extractTitle(from html: String) -> String {
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
        // Try to find article or main content tags
        let contentTags = ["<article[^>]*>", "<main[^>]*>", "<div[^>]*class=['\"].*article.*['\"][^>]*>", "<div[^>]*class=['\"].*content.*['\"][^>]*>"]

        for tag in contentTags {
            if let range = html.range(of: tag, options: .regularExpression) {
                let startIndex = range.upperBound
                // Find the closing tag
                let remaining = String(html[startIndex...])
                return remaining
            }
        }

        // If no specific content tag found, try to extract paragraphs
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
                if cleaned.count > 20 { // Only keep substantial paragraphs
                    paragraphs.append(decodeHTMLEntities(cleaned))
                }
            }
        }

        return paragraphs
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
