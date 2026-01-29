//
//  AddFeedView.swift
//  RSS RAIder
//

import SwiftUI

struct AddFeedView: View {
    @ObservedObject var feedsViewModel: FeedsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var feedName = ""
    @State private var feedURL = ""
    @State private var feedLogoURL: String?
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var isValid = false
    @State private var detectedMetadata: FeedMetadata?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        // Logo preview
                        if let logoURL = feedLogoURL {
                            CachedAsyncImage(urlString: logoURL, width: 44, height: 44, cornerRadius: 8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "newspaper")
                                        .foregroundColor(.gray)
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Nombre del feed", text: $feedName)
                                #if os(iOS)
                                .textContentType(.none)
                                #endif

                            if let description = detectedMetadata?.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }

                    TextField("URL del feed", text: $feedURL)
                        #if os(iOS)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        #endif
                        .onChange(of: feedURL) { _, newValue in
                            // Reset validation when URL changes
                            if !newValue.isEmpty && isValid {
                                isValid = false
                                validationMessage = ""
                            }
                        }
                } header: {
                    Text("Información del Feed")
                } footer: {
                    Text("Introduce la URL completa del feed RSS o Atom")
                }

                Section {
                    Button {
                        Task {
                            await validateFeed()
                        }
                    } label: {
                        HStack {
                            Text("Validar Feed")
                            Spacer()
                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(feedURL.isEmpty || isValidating)

                    if !validationMessage.isEmpty {
                        HStack {
                            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isValid ? .green : .red)
                            Text(validationMessage)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Validación")
                }
            }
            .navigationTitle("Añadir Feed RSS")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveFeed()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !feedName.isEmpty && !feedURL.isEmpty && isValid
    }

    private func validateFeed() async {
        isValidating = true
        validationMessage = ""
        isValid = false
        detectedMetadata = nil
        feedLogoURL = nil

        // First validate the feed URL
        let (valid, message) = await feedsViewModel.validateFeedURL(feedURL)

        if !valid {
            await MainActor.run {
                isValid = false
                validationMessage = message
                isValidating = false
            }
            return
        }

        // Now try to extract metadata from the website
        let metadata = await FeedMetadataExtractor.shared.extractMetadata(from: feedURL)

        await MainActor.run {
            isValid = true
            validationMessage = message
            detectedMetadata = metadata

            // Auto-fill name if empty
            if feedName.isEmpty {
                if let title = metadata.title, !title.isEmpty {
                    feedName = title
                } else if let url = URL(string: feedURL) {
                    // Fallback to host name
                    feedName = url.host?.replacingOccurrences(of: "www.", with: "") ?? "RSS Feed"
                }
            }

            // Set logo URL
            feedLogoURL = metadata.logoURL

            // Prefetch the logo image
            if let logoURL = metadata.logoURL {
                Task {
                    _ = await ImageCacheService.shared.loadImage(from: logoURL)
                }
            }

            isValidating = false
        }
    }

    private func saveFeed() {
        let feed = RSSFeed(name: feedName, url: feedURL, logoURL: feedLogoURL)
        feedsViewModel.addFeed(feed)
        dismiss()
    }
}

#Preview {
    AddFeedView(feedsViewModel: FeedsViewModel())
}
