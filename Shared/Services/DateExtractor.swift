//
//  DateExtractor.swift
//  RSS RAIder
//

import Foundation

/// Extracts publication dates from article text when RSS feed doesn't provide one
final class DateExtractor {
    static let shared = DateExtractor()

    private init() {}

    /// Attempts to extract a publication date from article text
    /// - Parameter text: The article text (title + body)
    /// - Returns: Extracted date or nil if not found
    func extractDate(from text: String) -> Date? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return nil }

        // Try various date patterns in order of reliability
        if let date = extractISO8601Date(from: cleanedText) {
            return date
        }

        if let date = extractFullDatePattern(from: cleanedText) {
            return date
        }

        if let date = extractRelativeDate(from: cleanedText) {
            return date
        }

        if let date = extractNumericDatePattern(from: cleanedText) {
            return date
        }

        return nil
    }

    // MARK: - ISO 8601 Dates

    private func extractISO8601Date(from text: String) -> Date? {
        // Pattern: 2024-01-15T10:30:00Z or similar
        let pattern = #"\b(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let matchRange = Range(match.range(at: 1), in: text) {
            let dateString = String(text[matchRange])
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateString)
        }

        return nil
    }

    // MARK: - Full Date Patterns

    private func extractFullDatePattern(from text: String) -> Date? {
        // English patterns: "January 15, 2024", "15 January 2024", "Jan 15, 2024"
        let englishPatterns = [
            #"\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})\b"#,
            #"\b(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})\b"#,
            #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+(\d{1,2}),?\s+(\d{4})\b"#,
            #"\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+(\d{4})\b"#
        ]

        // Spanish patterns: "15 de enero de 2024", "enero 15, 2024"
        let spanishPatterns = [
            #"\b(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+de\s+(\d{4})\b"#,
            #"\b(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+(\d{1,2}),?\s+(\d{4})\b"#
        ]

        // Try English patterns
        for pattern in englishPatterns {
            if let date = parseWithPattern(pattern, in: text, locale: Locale(identifier: "en_US_POSIX")) {
                return date
            }
        }

        // Try Spanish patterns
        for pattern in spanishPatterns {
            if let date = parseWithPattern(pattern, in: text, locale: Locale(identifier: "es_ES")) {
                return date
            }
        }

        return nil
    }

    private func parseWithPattern(_ pattern: String, in text: String, locale: Locale) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let matchRange = Range(match.range, in: text) {
            let dateString = String(text[matchRange])
            return parseDateString(dateString, locale: locale)
        }

        return nil
    }

    private func parseDateString(_ dateString: String, locale: Locale) -> Date? {
        let formats = [
            "MMMM d, yyyy",
            "MMMM d yyyy",
            "d MMMM yyyy",
            "MMM d, yyyy",
            "MMM d yyyy",
            "d MMM yyyy",
            "d 'de' MMMM 'de' yyyy",
            "MMMM d, yyyy"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = locale
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // MARK: - Relative Dates

    private func extractRelativeDate(from text: String) -> Date? {
        let now = Date()
        let calendar = Calendar.current
        let lowerText = text.lowercased()

        // Check for "today", "yesterday", etc.
        if lowerText.contains("today") || lowerText.contains("hoy") {
            return calendar.startOfDay(for: now)
        }

        if lowerText.contains("yesterday") || lowerText.contains("ayer") {
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        }

        // "X hours ago" / "hace X horas"
        if let hours = extractRelativeHours(from: lowerText) {
            return calendar.date(byAdding: .hour, value: -hours, to: now)
        }

        // "X days ago" / "hace X dias"
        if let days = extractRelativeDays(from: lowerText) {
            return calendar.date(byAdding: .day, value: -days, to: now)
        }

        // "X minutes ago" / "hace X minutos"
        if let minutes = extractRelativeMinutes(from: lowerText) {
            return calendar.date(byAdding: .minute, value: -minutes, to: now)
        }

        return nil
    }

    private func extractRelativeHours(from text: String) -> Int? {
        let patterns = [
            #"(\d+)\s*hours?\s*ago"#,
            #"hace\s*(\d+)\s*horas?"#
        ]

        for pattern in patterns {
            if let value = extractNumber(pattern: pattern, from: text) {
                return value
            }
        }

        return nil
    }

    private func extractRelativeDays(from text: String) -> Int? {
        let patterns = [
            #"(\d+)\s*days?\s*ago"#,
            #"hace\s*(\d+)\s*dias?"#
        ]

        for pattern in patterns {
            if let value = extractNumber(pattern: pattern, from: text) {
                return value
            }
        }

        return nil
    }

    private func extractRelativeMinutes(from text: String) -> Int? {
        let patterns = [
            #"(\d+)\s*minutes?\s*ago"#,
            #"hace\s*(\d+)\s*minutos?"#
        ]

        for pattern in patterns {
            if let value = extractNumber(pattern: pattern, from: text) {
                return value
            }
        }

        return nil
    }

    private func extractNumber(pattern: String, from text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           match.numberOfRanges > 1,
           let numRange = Range(match.range(at: 1), in: text) {
            return Int(text[numRange])
        }

        return nil
    }

    // MARK: - Numeric Date Patterns

    private func extractNumericDatePattern(from text: String) -> Date? {
        // Patterns: "01/15/2024", "15/01/2024", "2024-01-15", "15-01-2024"
        let patterns: [(String, String)] = [
            (#"\b(\d{4})-(\d{2})-(\d{2})\b"#, "yyyy-MM-dd"),
            (#"\b(\d{2})/(\d{2})/(\d{4})\b"#, "dd/MM/yyyy"),
            (#"\b(\d{2})-(\d{2})-(\d{4})\b"#, "dd-MM-yyyy")
        ]

        for (pattern, format) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let matchRange = Range(match.range, in: text) {
                let dateString = String(text[matchRange])
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = formatter.date(from: dateString) {
                    // Validate the date is reasonable (not in far future or past)
                    let now = Date()
                    let calendar = Calendar.current
                    if let yearsDiff = calendar.dateComponents([.year], from: date, to: now).year,
                       abs(yearsDiff) <= 10 {
                        return date
                    }
                }
            }
        }

        return nil
    }
}
