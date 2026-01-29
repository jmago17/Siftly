//
//  FeedMetadataExtractor.swift
//  RSS RAIder
//

import Foundation

struct FeedMetadata {
    let title: String?
    let logoURL: String?
    let description: String?
}

/// Extracts metadata (title, logo) from a website for improved feed detection
final class FeedMetadataExtractor {
    static let shared = FeedMetadataExtractor()

    private init() {}

    /// Extracts metadata from a feed URL or its parent website
    func extractMetadata(from feedURL: String) async -> FeedMetadata {
        guard let url = URL(string: feedURL) else {
            return FeedMetadata(title: nil, logoURL: nil, description: nil)
        }

        // First try to get the website's base URL
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil

        guard let baseURL = components?.url else {
            return FeedMetadata(title: nil, logoURL: nil, description: nil)
        }

        // Fetch the website HTML
        do {
            let request = URLRequest(url: baseURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            let (data, _) = try await URLSession.shared.data(for: request)
            let html = String(decoding: data, as: UTF8.self)

            let title = extractTitle(from: html)
            let logoURL = extractLogoURL(from: html, baseURL: baseURL)
            let description = extractDescription(from: html)

            return FeedMetadata(title: title, logoURL: logoURL, description: description)
        } catch {
            return FeedMetadata(title: nil, logoURL: nil, description: nil)
        }
    }

    /// Extracts the title from HTML
    private func extractTitle(from html: String) -> String? {
        // Try og:title first
        if let ogTitle = extractMetaContent(from: html, property: "og:title") {
            return cleanTitle(ogTitle)
        }

        // Try og:site_name
        if let siteName = extractMetaContent(from: html, property: "og:site_name") {
            return cleanTitle(siteName)
        }

        // Try twitter:title
        if let twitterTitle = extractMetaContent(from: html, name: "twitter:title") {
            return cleanTitle(twitterTitle)
        }

        // Try the <title> tag
        if let titleMatch = html.range(of: "(?i)<title[^>]*>([^<]+)</title>", options: .regularExpression) {
            let titleHTML = String(html[titleMatch])
            if let contentStart = titleHTML.range(of: ">"),
               let contentEnd = titleHTML.range(of: "</", options: .backwards) {
                let content = String(titleHTML[contentStart.upperBound..<contentEnd.lowerBound])
                return cleanTitle(content)
            }
        }

        return nil
    }

    /// Extracts the logo/favicon URL from HTML
    private func extractLogoURL(from html: String, baseURL: URL) -> String? {
        // Try apple-touch-icon (usually high quality)
        if let appleTouchIcon = extractLinkHref(from: html, rel: "apple-touch-icon") {
            return resolveURL(appleTouchIcon, baseURL: baseURL)
        }

        if let appleTouchIconPrecomposed = extractLinkHref(from: html, rel: "apple-touch-icon-precomposed") {
            return resolveURL(appleTouchIconPrecomposed, baseURL: baseURL)
        }

        // Try og:image (often a good logo)
        if let ogImage = extractMetaContent(from: html, property: "og:image") {
            return resolveURL(ogImage, baseURL: baseURL)
        }

        // Try icon link
        if let iconLink = extractLinkHref(from: html, rel: "icon") {
            return resolveURL(iconLink, baseURL: baseURL)
        }

        // Try shortcut icon
        if let shortcutIcon = extractLinkHref(from: html, rel: "shortcut icon") {
            return resolveURL(shortcutIcon, baseURL: baseURL)
        }

        // Fallback to /favicon.ico
        var faviconComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        faviconComponents?.path = "/favicon.ico"
        return faviconComponents?.url?.absoluteString
    }

    /// Extracts the description from HTML
    private func extractDescription(from html: String) -> String? {
        // Try og:description
        if let ogDesc = extractMetaContent(from: html, property: "og:description") {
            return ogDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try meta description
        if let metaDesc = extractMetaContent(from: html, name: "description") {
            return metaDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    // MARK: - Helpers

    private func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = "(?i)<meta[^>]+property=[\"']\(property)[\"'][^>]+content=[\"']([^\"']+)[\"']"
        let altPattern = "(?i)<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']\(property)[\"']"

        if let match = html.range(of: pattern, options: .regularExpression) {
            return extractContentValue(from: String(html[match]))
        }

        if let match = html.range(of: altPattern, options: .regularExpression) {
            return extractContentValue(from: String(html[match]))
        }

        return nil
    }

    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = "(?i)<meta[^>]+name=[\"']\(name)[\"'][^>]+content=[\"']([^\"']+)[\"']"
        let altPattern = "(?i)<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+name=[\"']\(name)[\"']"

        if let match = html.range(of: pattern, options: .regularExpression) {
            return extractContentValue(from: String(html[match]))
        }

        if let match = html.range(of: altPattern, options: .regularExpression) {
            return extractContentValue(from: String(html[match]))
        }

        return nil
    }

    private func extractContentValue(from tag: String) -> String? {
        let pattern = "content=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsTag = tag as NSString
        if let match = regex.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: nsTag.length)),
           match.numberOfRanges > 1 {
            return nsTag.substring(with: match.range(at: 1))
        }

        return nil
    }

    private func extractLinkHref(from html: String, rel: String) -> String? {
        // Handle both rel="icon" and rel="shortcut icon" patterns
        let escapedRel = NSRegularExpression.escapedPattern(for: rel)
        let pattern = "(?i)<link[^>]+rel=[\"'][^\"']*\(escapedRel)[^\"']*[\"'][^>]+href=[\"']([^\"']+)[\"']"
        let altPattern = "(?i)<link[^>]+href=[\"']([^\"']+)[\"'][^>]+rel=[\"'][^\"']*\(escapedRel)[^\"']*[\"']"

        if let match = html.range(of: pattern, options: .regularExpression) {
            return extractHrefValue(from: String(html[match]))
        }

        if let match = html.range(of: altPattern, options: .regularExpression) {
            return extractHrefValue(from: String(html[match]))
        }

        return nil
    }

    private func extractHrefValue(from tag: String) -> String? {
        let pattern = "href=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsTag = tag as NSString
        if let match = regex.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: nsTag.length)),
           match.numberOfRanges > 1 {
            return nsTag.substring(with: match.range(at: 1))
        }

        return nil
    }

    private func resolveURL(_ urlString: String, baseURL: URL) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Already absolute URL
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }

        // Protocol-relative URL
        if trimmed.hasPrefix("//") {
            return "https:\(trimmed)"
        }

        // Relative URL
        if let resolved = URL(string: trimmed, relativeTo: baseURL) {
            return resolved.absoluteString
        }

        return nil
    }

    private func cleanTitle(_ title: String) -> String {
        var cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common suffixes like " | Site Name", " - Site Name"
        let separators = [" | ", " - ", " – ", " — ", " :: ", " : "]
        for separator in separators {
            if let range = cleaned.range(of: separator) {
                // Take the shorter part (usually the site name)
                let beforeSep = String(cleaned[..<range.lowerBound])
                let afterSep = String(cleaned[range.upperBound...])

                // Prefer the shorter one as it's usually the site name
                if beforeSep.count < afterSep.count && beforeSep.count > 2 {
                    cleaned = beforeSep
                } else if afterSep.count > 2 {
                    cleaned = afterSep
                }
                break
            }
        }

        // Decode HTML entities
        cleaned = HTMLCleaner.decodeHTMLEntities(cleaned)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
