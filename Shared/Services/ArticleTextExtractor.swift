//
//  ArticleTextExtractor.swift
//  RSS RAIder
//

import Foundation
import NaturalLanguage
import CryptoKit

struct FeedItem {
    let title: String?
    let descriptionHTML: String?
    let contentHTML: String?
    let link: URL
}

enum ExtractionMethod: String, Codable {
    case rss_content
    case rss_description
    case fetched_html_readability
    case fetched_html_fallback
}

struct ExtractedArticleText: Codable {
    let title: String
    let body: String
    let paragraphs: [String]
    let sourceURL: URL
    let extractionMethod: ExtractionMethod
    let removedSections: [String]
    let confidence: Double
    let detectedLanguage: String?
    let wordCount: Int
    let hasPaywallHint: Bool
    let extractedPubDate: Date?
}

final class ArticleTextExtractor {
    static let shared = ArticleTextExtractor()

    private let cleaner = HTMLCleaner()
    private let scorer = ReadabilityScorer()
    private let noiseFilter = NoiseFilter()
    private let titleCleaner = TitleCleaner()
    private let cache = NSCache<NSString, ExtractedArticleTextBox>()

    private let minContentLength = 120
    private let minDescriptionLength = 80

    private init() {
        cache.countLimit = 200
    }

    func extract(from item: FeedItem) async -> ExtractedArticleText {
        let rssTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionHTML = item.descriptionHTML
        let contentHTML = item.contentHTML
        let signature = contentSignature(parts: [rssTitle ?? "", descriptionHTML ?? "", contentHTML ?? ""])
        let cacheKey = makeCacheKey(url: item.link, signature: signature)

        if let cached = cache.object(forKey: cacheKey)?.value {
            return cached
        }

        if let contentHTML = contentHTML,
           isSubstantialHTML(contentHTML, minLength: minContentLength),
           !isLikelyTruncated(contentHTML) {
            let result = extract(from: contentHTML, url: item.link, rssTitle: rssTitle, forcedMethod: .rss_content)
            cache.setObject(ExtractedArticleTextBox(result), forKey: cacheKey)
            return result
        }

        if let descriptionHTML = descriptionHTML,
           isSubstantialHTML(descriptionHTML, minLength: minDescriptionLength),
           !isLikelyTruncated(descriptionHTML) {
            let result = extract(from: descriptionHTML, url: item.link, rssTitle: rssTitle, forcedMethod: .rss_description)
            cache.setObject(ExtractedArticleTextBox(result), forKey: cacheKey)
            return result
        }

        do {
            let request = URLRequest(url: item.link, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
            let (data, _) = try await URLSession.shared.data(for: request)
            let html = HTMLCleaner.decodeHTML(data) ?? String(decoding: data, as: UTF8.self)
            let result = extract(from: html, url: item.link, rssTitle: rssTitle, forcedMethod: nil)
            cache.setObject(ExtractedArticleTextBox(result), forKey: cacheKey)
            return result
        } catch {
            let fallbackBody = textFromFallback(rssTitle: rssTitle, descriptionHTML: descriptionHTML, contentHTML: contentHTML, url: item.link)
            let result = ExtractedArticleText(
                title: fallbackBody.title,
                body: fallbackBody.body,
                paragraphs: fallbackBody.paragraphs,
                sourceURL: item.link,
                extractionMethod: .rss_description,
                removedSections: [],
                confidence: 0.3,
                detectedLanguage: detectLanguage(in: fallbackBody.body),
                wordCount: countWords(in: fallbackBody.body),
                hasPaywallHint: false,
                extractedPubDate: DateExtractor.shared.extractDate(from: fallbackBody.body)
            )
            cache.setObject(ExtractedArticleTextBox(result), forKey: cacheKey)
            return result
        }
    }

    func extract(from html: String, url: URL, rssTitle: String?) -> ExtractedArticleText {
        let signature = contentSignature(parts: [rssTitle ?? "", html])
        let cacheKey = makeCacheKey(url: url, signature: signature)
        if let cached = cache.object(forKey: cacheKey)?.value {
            return cached
        }

        let result = extract(from: html, url: url, rssTitle: rssTitle, forcedMethod: nil)
        cache.setObject(ExtractedArticleTextBox(result), forKey: cacheKey)
        return result
    }

    private func extract(from html: String, url: URL, rssTitle: String?, forcedMethod: ExtractionMethod?) -> ExtractedArticleText {
        let cleaned = cleaner.clean(html: html)
        let htmlTitle = titleCleaner.extractHTMLTitle(from: html)
        let h1Title = titleCleaner.extractFirstHeading(from: cleaned.html)
        let resolvedTitle = titleCleaner.resolveTitle(
            rssTitle: rssTitle,
            htmlTitle: htmlTitle,
            h1Title: h1Title,
            url: url
        )

        var removedSections = Set(cleaned.removedSections)
        let bestCandidate = scorer.bestCandidate(in: cleaned.html, rssTitle: rssTitle ?? resolvedTitle)
        let chosenHTML = bestCandidate?.html ?? cleaned.html
        let extractionMethod: ExtractionMethod = {
            if let forcedMethod = forcedMethod {
                return forcedMethod
            }
            return bestCandidate == nil ? .fetched_html_fallback : .fetched_html_readability
        }()

        let rawParagraphs = HTMLTextParser.extractParagraphs(from: chosenHTML)
        let normalized = TextCleaner.normalizeParagraphs(rawParagraphs)
        let filtered = noiseFilter.filter(normalized)
        removedSections.formUnion(filtered.removedSections)

        var paragraphs = filtered.paragraphs
        if paragraphs.isEmpty {
            let fallbackText = HTMLCleaner.decodeHTMLEntities(HTMLCleaner.stripTags(chosenHTML))
            let rawLines = fallbackText.components(separatedBy: "\n")
            paragraphs = TextCleaner.normalizeParagraphs(rawLines)
        }
        paragraphs = TextCleaner.removeDuplicateTitleParagraphs(paragraphs, title: resolvedTitle)

        let body = paragraphs.joined(separator: "\n\n")
        let hasPaywallHint = detectPaywall(in: html, bodyLength: body.count)
        let confidence = computeConfidence(
            method: extractionMethod,
            bodyLength: body.count,
            paragraphCount: paragraphs.count,
            hasPaywallHint: hasPaywallHint
        )

        let detectedLanguage = detectLanguage(in: body)
        let wordCount = countWords(in: body)

        // Try to extract publication date from HTML
        let extractedPubDate = extractDateFromHTML(html) ?? DateExtractor.shared.extractDate(from: body)

        let result = ExtractedArticleText(
            title: resolvedTitle,
            body: body,
            paragraphs: paragraphs,
            sourceURL: url,
            extractionMethod: extractionMethod,
            removedSections: Array(removedSections).sorted(),
            confidence: confidence,
            detectedLanguage: detectedLanguage,
            wordCount: wordCount,
            hasPaywallHint: hasPaywallHint,
            extractedPubDate: extractedPubDate
        )

        return result
    }

    private func extractDateFromHTML(_ html: String) -> Date? {
        // Try meta tags first (most reliable)
        if let date = extractMetaDate(from: html) {
            return date
        }

        // Try <time> elements with datetime attribute
        if let date = extractTimeElementDate(from: html) {
            return date
        }

        // Try JSON-LD structured data
        if let date = extractJSONLDDate(from: html) {
            return date
        }

        return nil
    }

    private func extractMetaDate(from html: String) -> Date? {
        // Common meta tags for publication date
        let patterns = [
            #"<meta\s+(?:property|name)=[\"'](?:article:published_time|og:article:published_time)[\"']\s+content=[\"']([^\"']+)[\"']"#,
            #"<meta\s+content=[\"']([^\"']+)[\"']\s+(?:property|name)=[\"'](?:article:published_time|og:article:published_time)[\"']"#,
            #"<meta\s+(?:property|name)=[\"'](?:date|pubdate|publish_date|published_date|datePublished)[\"']\s+content=[\"']([^\"']+)[\"']"#,
            #"<meta\s+content=[\"']([^\"']+)[\"']\s+(?:property|name)=[\"'](?:date|pubdate|publish_date|published_date|datePublished)[\"']"#
        ]

        for pattern in patterns {
            if let date = extractDateWithPattern(pattern, from: html) {
                return date
            }
        }

        return nil
    }

    private func extractTimeElementDate(from html: String) -> Date? {
        let pattern = #"<time[^>]+datetime=[\"']([^\"']+)[\"']"#
        return extractDateWithPattern(pattern, from: html)
    }

    private func extractJSONLDDate(from html: String) -> Date? {
        // Look for datePublished in JSON-LD
        let patterns = [
            #"\"datePublished\"\s*:\s*\"([^\"]+)\""#,
            #"\"dateCreated\"\s*:\s*\"([^\"]+)\""#
        ]

        for pattern in patterns {
            if let date = extractDateWithPattern(pattern, from: html) {
                return date
            }
        }

        return nil
    }

    private func extractDateWithPattern(_ pattern: String, from html: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsString = html as NSString
        if let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)),
           match.numberOfRanges > 1 {
            let dateString = nsString.substring(with: match.range(at: 1))
            return parseDateString(dateString)
        }

        return nil
    }

    private func parseDateString(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try ISO8601 formats
        let iso8601Full = ISO8601DateFormatter()
        iso8601Full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Full.date(from: trimmed) {
            return date
        }

        let iso8601Basic = ISO8601DateFormatter()
        iso8601Basic.formatOptions = [.withInternetDateTime]
        if let date = iso8601Basic.date(from: trimmed) {
            return date
        }

        // Try common date formats
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "EEE, dd MMM yyyy HH:mm:ss Z"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        // Fall back to DateExtractor for text-based dates
        return DateExtractor.shared.extractDate(from: trimmed)
    }

    private func textFromFallback(rssTitle: String?, descriptionHTML: String?, contentHTML: String?, url: URL) -> (title: String, body: String, paragraphs: [String]) {
        let title = titleCleaner.resolveTitle(rssTitle: rssTitle, htmlTitle: nil, h1Title: nil, url: url)
        let fallbackHTML = [contentHTML, descriptionHTML]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .max(by: { $0.count < $1.count }) ?? ""
        let paragraphs = TextCleaner.normalizeParagraphs([fallbackHTML]).filter { !$0.isEmpty }
        let body = paragraphs.joined(separator: "\n\n")
        if body.isEmpty {
            return (title, "", [])
        }
        return (title, body, paragraphs)
    }

    private func isSubstantialHTML(_ html: String, minLength: Int) -> Bool {
        let text = HTMLCleaner.decodeHTMLEntities(HTMLCleaner.stripTags(html))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= minLength
    }

    private func isLikelyTruncated(_ html: String) -> Bool {
        let text = HTMLCleaner.decodeHTMLEntities(HTMLCleaner.stripTags(html))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 60 else { return false }

        let normalized = TextCleaner.normalizedForComparison(trimmed)
        let indicatorPhrases = [
            "read more",
            "continue reading",
            "view more",
            "full story",
            "more at",
            "leer mas",
            "seguir leyendo",
            "continuar leyendo",
            "ver mas",
            "mas informacion",
            "mas info",
            "leer el articulo completo",
            "leer articulo completo",
            "leer nota completa"
        ]

        let tail = String(normalized.suffix(200))
        if indicatorPhrases.contains(where: { tail.contains($0) }) {
            return true
        }

        let trimmedLower = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLower.hasSuffix("...") || trimmedLower.hasSuffix("\u{2026}") {
            return true
        }

        let suffixWindow = String(trimmedLower.suffix(12))
        if suffixWindow.contains("[...]") || suffixWindow.contains("(...)") {
            return true
        }

        return false
    }

    private func detectPaywall(in html: String, bodyLength: Int) -> Bool {
        guard bodyLength < 400 else { return false }
        let normalized = TextCleaner.normalizedForComparison(html)
        let paywallKeywords = [
            "suscribete", "hazte suscriptor", "inicia sesion", "contenido exclusivo", "paywall",
            "subscription", "subscribe", "sign in", "login"
        ]
        if paywallKeywords.contains(where: { normalized.contains($0) }) {
            return true
        }

        let cookieKeywords = ["cookie", "cookies", "consent", "gdpr"]
        return cookieKeywords.contains(where: { normalized.contains($0) })
    }

    private func computeConfidence(method: ExtractionMethod, bodyLength: Int, paragraphCount: Int, hasPaywallHint: Bool) -> Double {
        var score: Double
        switch method {
        case .rss_content:
            score = 0.75
        case .rss_description:
            score = 0.62
        case .fetched_html_readability:
            score = 0.85
        case .fetched_html_fallback:
            score = 0.5
        }

        if bodyLength < 400 {
            score -= 0.15
        }
        if bodyLength < 200 {
            score -= 0.2
        }
        if paragraphCount < 2 {
            score -= 0.1
        }
        if hasPaywallHint {
            score -= 0.35
        }

        return max(0.0, min(1.0, score))
    }

    private func detectLanguage(in text: String) -> String? {
        guard text.count >= 60 else { return nil }
        let recognizer = NLLanguageRecognizer()
        let sample = String(text.prefix(1200))
        recognizer.processString(sample)
        return recognizer.dominantLanguage?.rawValue
    }

    private func countWords(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func contentSignature(parts: [String]) -> String {
        let combined = parts.joined(separator: "|")
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func makeCacheKey(url: URL, signature: String) -> NSString {
        NSString(string: "\(url.absoluteString)|\(signature)")
    }
}

private final class ExtractedArticleTextBox: NSObject {
    let value: ExtractedArticleText

    init(_ value: ExtractedArticleText) {
        self.value = value
    }
}

private enum HTMLTextParser {
    static func extractParagraphs(from html: String) -> [String] {
        var working = html
        working = working.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)

        let blockPattern = "(?is)<(p|li|blockquote|h1|h2|h3)[^>]*>(.*?)</\\1>"
        guard let regex = try? NSRegularExpression(pattern: blockPattern, options: []) else {
            return fallbackParagraphs(from: working)
        }

        let nsString = working as NSString
        let matches = regex.matches(in: working, options: [], range: NSRange(location: 0, length: nsString.length))
        var paragraphs: [String] = []

        for match in matches where match.numberOfRanges > 2 {
            let inner = nsString.substring(with: match.range(at: 2))
            let cleaned = HTMLCleaner.stripTags(inner)
            let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                paragraphs.append(trimmed)
            }
        }

        if paragraphs.isEmpty {
            return fallbackParagraphs(from: working)
        }

        return paragraphs
    }

    private static func fallbackParagraphs(from html: String) -> [String] {
        let stripped = HTMLCleaner.stripTags(html)
        let decoded = HTMLCleaner.decodeHTMLEntities(stripped)
        let lines = decoded
            .replacingOccurrences(of: "\\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines
    }
}
