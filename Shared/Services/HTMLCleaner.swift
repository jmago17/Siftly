//
//  HTMLCleaner.swift
//  RSS RAIder
//

import Foundation

struct CleanedHTML {
    let html: String
    let removedSections: [String]
}

struct HTMLCleaner {
    private let removeTagsWithContent = [
        "script", "style", "noscript", "svg", "canvas", "iframe", "form", "button", "input", "aside", "nav"
    ]

    private let selectorTokens: [String: String] = [
        // Cookie/consent
        "cookie": "cookie_banner",
        "consent": "cookie_banner",
        "gdpr": "cookie_banner",
        "privacy-banner": "cookie_banner",
        // Banners and overlays
        "banner": "banner",
        "modal": "overlay",
        "overlay": "overlay",
        "popup": "overlay",
        "lightbox": "overlay",
        // Subscribe/newsletter
        "subscribe": "subscribe",
        "newsletter": "subscribe",
        "signup": "subscribe",
        "sign-up": "subscribe",
        "mailchimp": "subscribe",
        "email-capture": "subscribe",
        // Paywall
        "paywall": "paywall",
        "premium-content": "paywall",
        "subscriber-only": "paywall",
        // Social sharing - expanded
        "share": "share",
        "sharing": "share",
        "social": "social",
        "social-share": "share",
        "social-buttons": "share",
        "share-buttons": "share",
        "share-bar": "share",
        "sharebar": "share",
        "sharetools": "share",
        "share-tools": "share",
        "addthis": "share",
        "sharethis": "share",
        "sharedaddy": "share",
        "post-share": "share",
        "article-share": "share",
        "sharing-icons": "share",
        "facebook-share": "share",
        "twitter-share": "share",
        "linkedin-share": "share",
        "whatsapp-share": "share",
        "email-share": "share",
        "print-share": "share",
        "copy-link": "share",
        // Related content
        "related": "related",
        "recommended": "related",
        "more-stories": "related",
        "also-read": "related",
        "read-next": "related",
        "you-may-like": "related",
        "outbrain": "related",
        "taboola": "related",
        "mgid": "related",
        "revcontent": "related",
        "zergnet": "related",
        // Comments
        "comments": "comments",
        "disqus": "comments",
        "comment-section": "comments",
        // Navigation/structure
        "footer": "footer",
        "header": "header",
        "nav": "nav",
        "sidebar": "sidebar",
        "widget": "widget",
        "breadcrumb": "nav",
        // Ads
        "advert": "ad",
        "ad-": "ad",
        "ads-": "ad",
        "advertisement": "ad",
        "sponsored": "ad",
        "promo": "promo",
        "dfp": "ad",
        "googletag": "ad",
        "adsense": "ad",
        // Author bio
        "author-bio": "author_box",
        "about-author": "author_box",
        "byline-block": "author_box"
    ]

    func clean(html: String) -> CleanedHTML {
        var result = html
        var removed: Set<String> = []

        result = removeHTMLComments(from: result)

        for tag in removeTagsWithContent {
            let (cleaned, removedTag) = removeTagAndContent(tag, from: result)
            result = cleaned
            if removedTag {
                removed.insert(tag)
            }
        }

        let (selectorCleaned, selectorRemoved) = removeElementsBySelectorTokens(from: result)
        result = selectorCleaned
        removed.formUnion(selectorRemoved)

        result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)

        return CleanedHTML(html: result, removedSections: Array(removed))
    }

    private func removeHTMLComments(from html: String) -> String {
        let pattern = "(?is)<!--.*?-->"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return html
        }
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else { return html }
        var result = html
        for match in matches.reversed() {
            result = (result as NSString).replacingCharacters(in: match.range, with: "")
        }
        return result
    }

    private func removeTagAndContent(_ tag: String, from html: String) -> (String, Bool) {
        let pattern = "(?is)<\(tag)[^>]*>.*?</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (html, false)
        }
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else { return (html, false) }
        var result = html
        for match in matches.reversed() {
            result = (result as NSString).replacingCharacters(in: match.range, with: "")
        }
        return (result, true)
    }

    private func removeElementsBySelectorTokens(from html: String) -> (String, Set<String>) {
        let tokens = selectorTokens.keys.sorted { $0.count > $1.count }
        let tokenPattern = tokens.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let pattern = "(?is)<([a-z0-9]+)([^>]*(id|class)\\s*=\\s*['\"][^'\"]*(\(tokenPattern))[^'\"]*['\"][^>]*)>.*?</\\1>"
        let selfClosingPattern = "(?is)<([a-z0-9]+)([^>]*(id|class)\\s*=\\s*['\"][^'\"]*(\(tokenPattern))[^'\"]*['\"][^>]*)/?>"

        var removed: Set<String> = []
        var result = html

        result = removeByPattern(pattern, from: result, removed: &removed)
        result = removeByPattern(selfClosingPattern, from: result, removed: &removed)

        return (result, removed)
    }

    private func removeByPattern(_ pattern: String, from html: String, removed: inout Set<String>) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return html
        }

        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else { return html }

        var result = html
        for match in matches.reversed() {
            if match.numberOfRanges > 2 {
                let attributes = nsString.substring(with: match.range(at: 2)).lowercased()
                for (token, label) in selectorTokens {
                    if attributes.contains(token) {
                        removed.insert(label)
                    }
                }
            }
            result = (result as NSString).replacingCharacters(in: match.range, with: "")
        }

        return result
    }

    static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&mdash;": "-",
            "&ndash;": "-",
            "&hellip;": "...",
            "&copy;": "(c)",
            "&reg;": "(r)",
            "&trade;": "(tm)"
        ]

        for (entity, value) in entities {
            result = result.replacingOccurrences(of: entity, with: value)
        }

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
                        result = (result as NSString).replacingCharacters(in: match.range, with: char)
                    }
                }
            }
        }

        return result
    }

    static func decodeHTML(_ data: Data) -> String? {
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
}
