//
//  SafariReaderView.swift
//  RSS RAIder
//

import SwiftUI

struct SafariReaderView: View {
    let url: URL

    var body: some View {
        #if os(iOS)
        SafariReaderRepresentable(url: url)
        #else
        Text("Safari Reader no disponible en esta plataforma.")
        #endif
    }
}

#if os(iOS)
import SafariServices

struct SafariReaderRepresentable: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {
        // No updates needed.
    }
}
#endif

#Preview {
    SafariReaderView(url: URL(string: "https://example.com")!)
}
