//
//  RSSRAIderApp.swift
//  RSS RAIder
//
//  AI-powered RSS reader with smart filtering
//

import SwiftUI

@main
struct RSSRAIderApp: App {
    init() {
        // Set default preferences if not already set
        if UserDefaults.standard.object(forKey: "openInAppBrowser") == nil {
            UserDefaults.standard.set(true, forKey: "openInAppBrowser")
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["ARTICLE_TEXT_TESTS"] == "1" {
            ArticleTextExtractorTestHarness.run()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
