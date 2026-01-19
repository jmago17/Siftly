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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
