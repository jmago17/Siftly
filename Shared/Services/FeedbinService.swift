//
//  FeedbinService.swift
//  RSS RAIder
//

import Foundation

struct FeedbinCredentials: Codable, Equatable {
    let username: String
    let password: String
}

struct FeedbinSubscription: Decodable, Identifiable {
    let id: Int
    let feedID: Int
    let title: String?
    let feedURL: String
    let siteURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case feedID = "feed_id"
        case title
        case feedURL = "feed_url"
        case siteURL = "site_url"
    }
}

struct FeedbinEntry: Decodable, Identifiable {
    let id: Int
    let feedID: Int
    let title: String?
    let url: String?
    let author: String?
    let content: String?
    let summary: String?
    let published: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case feedID = "feed_id"
        case title
        case url
        case author
        case content
        case summary
        case published
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        feedID = try container.decode(Int.self, forKey: .feedID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)

        let publishedString = try container.decodeIfPresent(String.self, forKey: .published)
        published = FeedbinDateParser.parse(publishedString)

        let createdString = try container.decodeIfPresent(String.self, forKey: .createdAt)
        createdAt = FeedbinDateParser.parse(createdString)
    }
}

enum FeedbinError: LocalizedError {
    case missingCredentials
    case invalidURL
    case httpError(Int)
    case decodingFailed
    case subscriptionNotFound

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Feedbin credentials are missing."
        case .invalidURL:
            return "Invalid Feedbin URL."
        case .httpError(let code):
            return "Feedbin request failed with status \(code)."
        case .decodingFailed:
            return "Failed to decode Feedbin response."
        case .subscriptionNotFound:
            return "Feed not found in Feedbin subscriptions."
        }
    }
}

final class FeedbinService {
    static let shared = FeedbinService()

    private let baseURL = URL(string: "https://api.feedbin.com/v2")!
    private let credentialsKey = "feedbinCredentials"
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    var credentials: FeedbinCredentials? {
        get {
            guard let data = UserDefaults.standard.data(forKey: credentialsKey) else {
                return nil
            }
            return try? JSONDecoder().decode(FeedbinCredentials.self, from: data)
        }
        set {
            if let newValue = newValue {
                let data = try? JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: credentialsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: credentialsKey)
            }
        }
    }

    var hasCredentials: Bool {
        guard let creds = credentials else { return false }
        return !creds.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !creds.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateCredentials(username: String, password: String) {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty, !trimmedPass.isEmpty else {
            credentials = nil
            return
        }
        credentials = FeedbinCredentials(username: trimmedUser, password: trimmedPass)
    }

    func testConnection() async throws -> Int {
        let subs = try await fetchSubscriptions()
        return subs.count
    }

    func fetchEntries(for feedURL: String, limit: Int = 50) async throws -> (FeedbinSubscription, [FeedbinEntry]) {
        let subscriptions = try await fetchSubscriptions()
        let normalizedTarget = normalizeFeedURL(feedURL)

        let match: FeedbinSubscription? = {
            if let direct = subscriptions.first(where: { normalizeFeedURL($0.feedURL) == normalizedTarget }) {
                return direct
            }
            return fuzzyMatchSubscription(targetURL: feedURL, subscriptions: subscriptions)
        }()

        guard let match else {
            throw FeedbinError.subscriptionNotFound
        }

        let entries = try await fetchEntries(feedID: match.feedID, limit: limit)
        return (match, entries)
    }

    private func fetchSubscriptions() async throws -> [FeedbinSubscription] {
        let url = baseURL.appendingPathComponent("subscriptions.json")
        return try await performRequest(url: url, decode: [FeedbinSubscription].self)
    }

    private func fetchEntries(feedID: Int, limit: Int) async throws -> [FeedbinEntry] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("entries.json"), resolvingAgainstBaseURL: false) else {
            throw FeedbinError.invalidURL
        }

        let cappedLimit = max(1, min(limit, 100))
        components.queryItems = [
            URLQueryItem(name: "feed_id", value: "\(feedID)"),
            URLQueryItem(name: "per_page", value: "\(cappedLimit)"),
            URLQueryItem(name: "mode", value: "extended")
        ]

        guard let url = components.url else {
            throw FeedbinError.invalidURL
        }

        return try await performRequest(url: url, decode: [FeedbinEntry].self)
    }

    private func performRequest<T: Decodable>(url: URL, decode type: T.Type) async throws -> T {
        guard let creds = credentials else { throw FeedbinError.missingCredentials }

        var request = URLRequest(url: url)
        request.setValue("RSSFilter/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(basicAuthHeader(username: creds.username, password: creds.password), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbinError.httpError(-1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw FeedbinError.httpError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw FeedbinError.decodingFailed
        }
    }

    private func basicAuthHeader(username: String, password: String) -> String {
        let auth = "\(username):\(password)"
        let data = Data(auth.utf8).base64EncodedString()
        return "Basic \(data)"
    }

    private func normalizeFeedURL(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let components = URLComponents(string: trimmed) else {
            return trimmed
        }

        let host = (components.host ?? "").replacingOccurrences(of: "www.", with: "")
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            return host
        }
        return "\(host)/\(path)"
    }

    private func fuzzyMatchSubscription(targetURL: String, subscriptions: [FeedbinSubscription]) -> FeedbinSubscription? {
        guard let targetComponents = URLComponents(string: targetURL.lowercased()) else {
            return nil
        }

        let targetHost = (targetComponents.host ?? "").replacingOccurrences(of: "www.", with: "")
        let targetPath = targetComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !targetHost.isEmpty else { return nil }

        var bestMatch: (FeedbinSubscription, Int)?

        for subscription in subscriptions {
            guard let subComponents = URLComponents(string: subscription.feedURL.lowercased()) else { continue }
            let subHost = (subComponents.host ?? "").replacingOccurrences(of: "www.", with: "")

            let hostMatches = subHost == targetHost || siteHostMatches(targetHost: targetHost, siteURL: subscription.siteURL)
            guard hostMatches else { continue }

            let subPath = subComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let isPathCompatible = subPath.isEmpty || targetPath.isEmpty || subPath.contains(targetPath) || targetPath.contains(subPath)

            guard isPathCompatible else { continue }

            let distance = abs(subPath.count - targetPath.count)
            if let current = bestMatch {
                if distance < current.1 {
                    bestMatch = (subscription, distance)
                }
            } else {
                bestMatch = (subscription, distance)
            }
        }

        return bestMatch?.0
    }

    private func siteHostMatches(targetHost: String, siteURL: String?) -> Bool {
        guard let siteURL, let siteHost = URL(string: siteURL)?.host?.lowercased() else { return false }
        return siteHost.replacingOccurrences(of: "www.", with: "") == targetHost
    }
}

private enum FeedbinDateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let iso8601 = ISO8601DateFormatter()
        if let date = iso8601.date(from: value) {
            return date
        }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: value) {
            return date
        }

        return nil
    }
}
