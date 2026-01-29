//
//  TextCleaner.swift
//  RSS RAIder
//

import Foundation

enum TextCleaner {
    static func normalizeParagraphs(_ paragraphs: [String]) -> [String] {
        paragraphs.compactMap { paragraph in
            var text = HTMLCleaner.stripTags(paragraph)
            text = HTMLCleaner.decodeHTMLEntities(text)
            text = stripURLs(from: text)
            text = removeUTMParameters(in: text)
            text = stripSocialSharePatterns(from: text)
            text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    /// Strips common social share button text patterns from plain text
    static func stripSocialSharePatterns(from text: String) -> String {
        var result = text

        // Remove share counts like "0 shares", "123 Compartir", etc.
        let shareCountPatterns = [
            "\\d+\\s*(shares?|compartir|compartido|compartidos|likes?|comments?|comentarios?)",
            "(shares?|compartir)\\s*\\d+",
            "\\d+\\s*(facebook|twitter|linkedin|whatsapp|email)\\s*\\d*",
        ]

        for pattern in shareCountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }

        // Remove standalone social network names (when they appear as button labels)
        let socialButtonPatterns = [
            // Share action patterns
            "(?i)\\b(share|compartir)\\s+(on|en|via|por)?\\s*(facebook|twitter|x|linkedin|whatsapp|telegram|pinterest|reddit|email|correo)\\b",
            "(?i)\\b(tweet|pin it|me gusta|like)\\b",
            // Standalone at beginning/end of line
            "(?i)^\\s*(facebook|twitter|x|linkedin|whatsapp|telegram|pinterest|reddit|email|print|imprimir|copiar|copy)\\s*$",
        ]

        for pattern in socialButtonPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }

        // Remove emoji share indicators
        let emojiPatterns = ["📧", "📱", "🔗", "📤", "💬", "🐦", "📘", "🔵"]
        for emoji in emojiPatterns {
            result = result.replacingOccurrences(of: emoji, with: "")
        }

        return result
    }

    /// Comprehensive text cleaning for AI summarization
    static func cleanForSummarization(_ text: String) -> String {
        var cleaned = text

        // First strip any remaining HTML
        cleaned = HTMLCleaner.stripTags(cleaned)
        cleaned = HTMLCleaner.decodeHTMLEntities(cleaned)

        // Remove URLs
        cleaned = stripURLs(from: cleaned)
        cleaned = removeUTMParameters(in: cleaned)

        // Remove social share patterns
        cleaned = stripSocialSharePatterns(from: cleaned)

        // Remove common boilerplate phrases
        let boilerplatePhrases = [
            "(?i)read more\\.{0,3}$",
            "(?i)continue reading\\.{0,3}$",
            "(?i)leer m[aá]s\\.{0,3}$",
            "(?i)seguir leyendo\\.{0,3}$",
            "(?i)click here to .*$",
            "(?i)tap here to .*$",
            "(?i)subscribe to .*$",
            "(?i)suscr[ií]bete a .*$",
            "(?i)follow us on .*$",
            "(?i)s[ií]guenos en .*$",
            "(?i)^\\s*advertisement\\s*$",
            "(?i)^\\s*publicidad\\s*$",
            "(?i)^\\s*sponsored\\s*$",
            "(?i)^\\s*patrocinado\\s*$",
            "(?i)^\\s*related:?\\s*$",
            "(?i)^\\s*relacionado:?\\s*$",
            "(?i)^\\s*tags?:.*$",
            "(?i)^\\s*etiquetas?:.*$",
            "(?i)^\\s*categor[ií]as?:.*$",
            "(?i)^\\s*share this (article|story|post).*$",
            "(?i)^\\s*comparte este (art[ií]culo|post).*$",
        ]

        for pattern in boilerplatePhrases {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }

        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    static func stripURLs(from text: String) -> String {
        let pattern = "(?i)\\b(https?://\\S+|www\\.\\S+)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        var result = text
        for match in matches.reversed() {
            result = (result as NSString).replacingCharacters(in: match.range, with: "")
        }
        return result
    }

    static func removeUTMParameters(in text: String) -> String {
        let pattern = "(?i)utm_[a-z0-9_]+=\\S+"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    static func removeDuplicateTitleParagraphs(_ paragraphs: [String], title: String) -> [String] {
        guard let first = paragraphs.first else { return paragraphs }
        let normalizedTitle = normalizedForComparison(title)
        let normalizedFirst = normalizedForComparison(first)

        if !normalizedTitle.isEmpty && (normalizedFirst == normalizedTitle || normalizedFirst.hasPrefix(normalizedTitle)) {
            return Array(paragraphs.dropFirst())
        }

        return paragraphs
    }

    static func normalizedForComparison(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
        let stripped = folded.replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
        return stripped.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
