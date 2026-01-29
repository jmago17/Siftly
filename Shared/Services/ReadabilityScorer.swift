//
//  ReadabilityScorer.swift
//  RSS RAIder
//

import Foundation

struct ReadabilityCandidate {
    let html: String
    let score: Double
}

struct ReadabilityScorer {
    func bestCandidate(in html: String, rssTitle: String?) -> ReadabilityCandidate? {
        if let articleCandidate = bestCandidate(in: html, tag: "article", rssTitle: rssTitle) {
            return articleCandidate
        }

        if let mainCandidate = bestCandidate(in: html, tag: "main", rssTitle: rssTitle) {
            return mainCandidate
        }

        let candidates = extractCandidates(from: html, tags: ["div", "section"])
        let scored = candidates.map { candidate in
            ReadabilityCandidate(html: candidate, score: scoreCandidate(candidate, rssTitle: rssTitle))
        }

        guard let best = scored.max(by: { $0.score < $1.score }), best.score >= 220 else {
            return nil
        }

        return best
    }

    private func bestCandidate(in html: String, tag: String, rssTitle: String?) -> ReadabilityCandidate? {
        let candidates = extractCandidates(from: html, tags: [tag])
        let scored = candidates.map { candidate in
            ReadabilityCandidate(html: candidate, score: scoreCandidate(candidate, rssTitle: rssTitle))
        }
        guard let best = scored.max(by: { $0.score < $1.score }), best.score >= 180 else {
            return nil
        }
        return best
    }

    private func extractCandidates(from html: String, tags: [String]) -> [String] {
        var results: [String] = []

        for tag in tags {
            let pattern = "(?is)<\(tag)[^>]*>(.*?)</\(tag)>"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches where match.numberOfRanges > 1 {
                let inner = nsString.substring(with: match.range(at: 1))
                if !inner.isEmpty {
                    results.append(inner)
                }
            }
        }

        return results
    }

    private func scoreCandidate(_ html: String, rssTitle: String?) -> Double {
        let text = HTMLCleaner.decodeHTMLEntities(HTMLCleaner.stripTags(html))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let textLength = trimmed.count
        if textLength < 120 {
            return Double(textLength)
        }

        let linkTextLength = extractLinkTextLength(from: html)
        let paragraphCount = countMatches(in: html, pattern: "<p\\b")
        let commaCount = trimmed.filter { $0 == "," }.count
        let formCount = countMatches(in: html, pattern: "<form\\b")
        let buttonCount = countMatches(in: html, pattern: "<button\\b")
        let shortLineCount = trimmed
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count < 40 }
            .count

        var score = Double(max(0, textLength - linkTextLength))
        score += Double(paragraphCount) * 50.0
        score += Double(commaCount) * 20.0
        score -= Double(formCount) * 200.0
        score -= Double(buttonCount) * 50.0
        score -= Double(shortLineCount) * 15.0

        let linkDensity = textLength > 0 ? Double(linkTextLength) / Double(textLength) : 0
        if linkDensity > 0.35 {
            score -= 120
        } else if linkDensity > 0.2 {
            score -= 60
        }

        if let rssTitle = rssTitle, !rssTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += titleMatchBoost(rssTitle: rssTitle, html: html, text: trimmed)
        }

        return score
    }

    private func titleMatchBoost(rssTitle: String, html: String, text: String) -> Double {
        let normalizedTitle = TextCleaner.normalizedForComparison(rssTitle)
        if normalizedTitle.isEmpty { return 0 }

        let normalizedText = TextCleaner.normalizedForComparison(text)
        if normalizedText.contains(normalizedTitle) {
            return 200
        }

        let headingMatch = extractHeadings(from: html).contains { heading in
            let normalizedHeading = TextCleaner.normalizedForComparison(heading)
            return normalizedHeading.contains(normalizedTitle) || normalizedTitle.contains(normalizedHeading)
        }

        if headingMatch {
            return 120
        }

        let overlapScore = tokenOverlapScore(title: normalizedTitle, content: normalizedText)
        if overlapScore >= 0.6 {
            return 120
        }
        if overlapScore >= 0.4 {
            return 60
        }

        return 0
    }

    private func extractHeadings(from html: String) -> [String] {
        let pattern = "(?is)<h[1-3][^>]*>(.*?)</h[1-3]>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let inner = nsString.substring(with: match.range(at: 1))
            let stripped = HTMLCleaner.decodeHTMLEntities(HTMLCleaner.stripTags(inner))
            let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private func tokenOverlapScore(title: String, content: String) -> Double {
        let titleTokens = Set(title.split(separator: " ").map(String.init).filter { $0.count > 3 })
        let contentTokens = Set(content.split(separator: " ").map(String.init))
        guard !titleTokens.isEmpty else { return 0 }
        let overlap = titleTokens.intersection(contentTokens)
        return Double(overlap.count) / Double(titleTokens.count)
    }

    private func extractLinkTextLength(from html: String) -> Int {
        let pattern = "(?is)<a[^>]*>(.*?)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        var total = 0
        for match in matches where match.numberOfRanges > 1 {
            let inner = nsString.substring(with: match.range(at: 1))
            let stripped = HTMLCleaner.decodeHTMLEntities(HTMLCleaner.stripTags(inner))
            total += stripped.count
        }
        return total
    }

    private func countMatches(in text: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        let nsString = text as NSString
        return regex.numberOfMatches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
    }
}
