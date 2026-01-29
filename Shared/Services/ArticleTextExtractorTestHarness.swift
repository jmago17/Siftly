//
//  ArticleTextExtractorTestHarness.swift
//  RSS RAIder
//

import Foundation

#if DEBUG
enum ArticleTextExtractorTestHarness {
    static func run() {
        testNormalArticle()
        testCookieBannerRemoval()
        testPaywallDetection()
        testRelatedLinksRemoval()
        print("[ArticleTextExtractorTestHarness] All tests passed.")
    }

    private static func testNormalArticle() {
        let result = extractFixture(named: "normal_article")
        assert(!result.body.isEmpty)
        assert(result.paragraphs.count >= 2)
        assert(result.confidence >= 0.7)
        assert(!result.body.lowercased().contains("script"))
    }

    private static func testCookieBannerRemoval() {
        let result = extractFixture(named: "cookie_banner")
        assert(result.removedSections.contains("cookie_banner"))
        let normalized = result.body.lowercased()
        assert(!normalized.contains("cookies"))
        assert(result.paragraphs.count >= 2)
    }

    private static func testPaywallDetection() {
        let result = extractFixture(named: "paywall_stub")
        assert(result.hasPaywallHint)
        assert(result.confidence <= 0.6)
    }

    private static func testRelatedLinksRemoval() {
        let result = extractFixture(named: "related_links")
        assert(result.removedSections.contains("related"))
        assert(result.paragraphs.count >= 2)
    }

    private static func extractFixture(named name: String) -> ExtractedArticleText {
        guard let url = Bundle.main.url(forResource: name, withExtension: "html", subdirectory: "Fixtures/ArticleText"),
              let html = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Fixture not found: \(name)")
        }

        let sourceURL = URL(string: "https://example.com/\(name)")!
        return ArticleTextExtractor.shared.extract(from: html, url: sourceURL, rssTitle: nil)
    }
}
#endif
