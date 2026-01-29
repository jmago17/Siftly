//
//  TitleCleaner.swift
//  RSS RAIder
//

import Foundation

struct TitleCleaner {
    func resolveTitle(rssTitle: String?, htmlTitle: String?, h1Title: String?, url: URL) -> String {
        let cleanedRSS = cleanTitle(rssTitle, url: url)
        let cleanedHTML = cleanTitle(htmlTitle, url: url)
        let cleanedH1 = cleanTitle(h1Title, url: url)

        if let rss = cleanedRSS, !rss.isEmpty {
            if let h1 = cleanedH1, !h1.isEmpty, isSimilar(rss, h1) {
                return h1
            }
            return rss
        }

        if let h1 = cleanedH1, !h1.isEmpty {
            return h1
        }

        if let html = cleanedHTML, !html.isEmpty {
            return html
        }

        return "Articulo"
    }

    func extractHTMLTitle(from html: String) -> String? {
        let pattern = "(?is)<title[^>]*>(.*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = html as NSString
        guard let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        let inner = nsString.substring(with: match.range(at: 1))
        let stripped = HTMLCleaner.decodeHTMLEntities(HTMLCleaner.stripTags(inner))
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func extractFirstHeading(from html: String) -> String? {
        let pattern = "(?is)<h1[^>]*>(.*?)</h1>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = html as NSString
        guard let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        let inner = nsString.substring(with: match.range(at: 1))
        let stripped = HTMLCleaner.decodeHTMLEntities(HTMLCleaner.stripTags(inner))
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func cleanTitle(_ title: String?, url: URL) -> String? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }

        let stripped = stripSiteSuffix(from: title, url: url)
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripSiteSuffix(from title: String, url: URL) -> String {
        let separators = [" | ", " - ", " — ", " • ", " :: "]
        guard let host = url.host?.lowercased() else { return title }
        let hostToken = host.replacingOccurrences(of: "www.", with: "")

        for separator in separators {
            let parts = title.components(separatedBy: separator)
            if parts.count < 2 { continue }
            let suffix = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let normalizedSuffix = TextCleaner.normalizedForComparison(suffix)

            if normalizedSuffix.contains(TextCleaner.normalizedForComparison(hostToken))
                || normalizedSuffix.contains("com")
                || normalizedSuffix.contains("net") {
                return parts.dropLast().joined(separator: separator)
            }

            let wordCount = normalizedSuffix.split(separator: " ").count
            if wordCount <= 3 {
                return parts.dropLast().joined(separator: separator)
            }
        }

        return title
    }

    private func isSimilar(_ lhs: String, _ rhs: String) -> Bool {
        let left = TextCleaner.normalizedForComparison(lhs)
        let right = TextCleaner.normalizedForComparison(rhs)
        if left.isEmpty || right.isEmpty { return false }
        if left.contains(right) || right.contains(left) {
            return true
        }

        let leftTokens = Set(left.split(separator: " ").map(String.init))
        let rightTokens = Set(right.split(separator: " ").map(String.init))
        let overlap = leftTokens.intersection(rightTokens)
        let ratio = Double(overlap.count) / Double(max(leftTokens.count, 1))
        return ratio >= 0.6
    }
}
