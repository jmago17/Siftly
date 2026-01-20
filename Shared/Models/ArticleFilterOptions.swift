//
//  ArticleFilterOptions.swift
//  RSS RAIder
//

import Foundation

enum FilterMatchMode: String, CaseIterable, Identifiable, Codable {
    case all
    case any
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "Todas"
        case .any:
            return "Cualquiera"
        case .none:
            return "Ninguna"
        }
    }
}

enum RelativeDateUnit: String, CaseIterable, Identifiable, Codable {
    case hours
    case days
    case weeks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hours:
            return "horas"
        case .days:
            return "dias"
        case .weeks:
            return "semanas"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .hours:
            return 3600
        case .days:
            return 86400
        case .weeks:
            return 604800
        }
    }
}

enum RelativeDateComparison: String, CaseIterable, Identifiable, Codable {
    case withinLast
    case olderThan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .withinLast:
            return "Ultimos"
        case .olderThan:
            return "Anteriores a"
        }
    }
}

struct ArticleFilterOptions: Codable, Equatable {
    var matchMode: FilterMatchMode
    var contentQuery: String
    var urlQuery: String
    var feedTitleQuery: String
    var authorQuery: String
    var useExactDate: Bool
    var exactDate: Date
    var useRelativeDate: Bool
    var relativeValue: Int
    var relativeUnit: RelativeDateUnit
    var relativeComparison: RelativeDateComparison

    init(
        matchMode: FilterMatchMode = .all,
        contentQuery: String = "",
        urlQuery: String = "",
        feedTitleQuery: String = "",
        authorQuery: String = "",
        useExactDate: Bool = false,
        exactDate: Date = Date(),
        useRelativeDate: Bool = false,
        relativeValue: Int = 1,
        relativeUnit: RelativeDateUnit = .days,
        relativeComparison: RelativeDateComparison = .withinLast
    ) {
        self.matchMode = matchMode
        self.contentQuery = contentQuery
        self.urlQuery = urlQuery
        self.feedTitleQuery = feedTitleQuery
        self.authorQuery = authorQuery
        self.useExactDate = useExactDate
        self.exactDate = exactDate
        self.useRelativeDate = useRelativeDate
        self.relativeValue = relativeValue
        self.relativeUnit = relativeUnit
        self.relativeComparison = relativeComparison
    }

    func matches(content: String, url: String, feedTitle: String, author: String?, date: Date?) -> Bool {
        var conditions: [Bool] = []

        let trimmedContent = contentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            conditions.append(containsMatch(haystack: content, needle: trimmedContent))
        }

        let trimmedURL = urlQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty {
            conditions.append(containsMatch(haystack: url, needle: trimmedURL))
        }

        let trimmedFeed = feedTitleQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFeed.isEmpty {
            conditions.append(containsMatch(haystack: feedTitle, needle: trimmedFeed))
        }

        let trimmedAuthor = authorQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAuthor.isEmpty {
            let authorValue = author ?? ""
            conditions.append(containsMatch(haystack: authorValue, needle: trimmedAuthor))
        }

        if useExactDate {
            let matchesDate = date.map { Calendar.current.isDate($0, inSameDayAs: exactDate) } ?? false
            conditions.append(matchesDate)
        }

        if useRelativeDate && relativeValue > 0 {
            let matchesRelative = date.map { matchesRelativeDate($0) } ?? false
            conditions.append(matchesRelative)
        }

        guard !conditions.isEmpty else { return true }

        switch matchMode {
        case .all:
            return conditions.allSatisfy { $0 }
        case .any:
            return conditions.contains(true)
        case .none:
            return !conditions.contains(true)
        }
    }

    var hasActiveFilters: Bool {
        let textFilters = [
            contentQuery, urlQuery, feedTitleQuery, authorQuery
        ].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return textFilters || useExactDate || (useRelativeDate && relativeValue > 0)
    }

    private func matchesRelativeDate(_ date: Date) -> Bool {
        let seconds = Double(relativeValue) * relativeUnit.seconds
        let threshold = Date().addingTimeInterval(-seconds)
        switch relativeComparison {
        case .withinLast:
            return date >= threshold
        case .olderThan:
            return date < threshold
        }
    }

    private func containsMatch(haystack: String, needle: String) -> Bool {
        let normalizedHaystack = normalize(haystack)
        let normalizedNeedle = normalize(needle)
        guard !normalizedNeedle.isEmpty else { return true }
        return normalizedHaystack.contains(normalizedNeedle)
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
    }
}
