//
//  TextReaderView.swift
//  RSS RAIder
//

import SwiftUI

struct TextReaderView: View {
    let url: String
    let title: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechService = SpeechService()

    @State private var articleContent: ArticleContent?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var fontSize: CGFloat = 18

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Extrayendo texto...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") {
                            Task {
                                await loadArticle()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let content = articleContent {
                    // Article text
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(content.title)
                                .font(.title)
                                .fontWeight(.bold)

                            Text(content.text)
                                .font(.system(size: fontSize))
                                .lineSpacing(8)
                                .textSelection(.enabled)
                        }
                        .padding()
                    }

                    Divider()

                    // Player controls
                    PlayerControlsView(
                        speechService: speechService,
                        fontSize: $fontSize,
                        articleText: content.text
                    )
                }
            }
            .navigationTitle("Leer Artículo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        speechService.stop()
                        dismiss()
                    }
                }
            }
            .task {
                await loadArticle()
            }
            .onDisappear {
                speechService.stop()
            }
        }
    }

    private func loadArticle() async {
        isLoading = true
        errorMessage = nil

        do {
            let content = try await HTMLTextExtractor.shared.extractText(from: url)
            articleContent = content
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct PlayerControlsView: View {
    @ObservedObject var speechService: SpeechService
    @Binding var fontSize: CGFloat
    let articleText: String

    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: speechService.progress)
                .padding(.horizontal)

            // Main controls
            HStack(spacing: 32) {
                // Skip backward
                Button {
                    speechService.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }

                // Play/Pause
                Button {
                    if speechService.isPlaying {
                        speechService.pause()
                    } else {
                        if speechService.progress == 0 || speechService.progress == 1.0 {
                            speechService.speak(text: articleText)
                        } else {
                            speechService.resume()
                        }
                    }
                } label: {
                    Image(systemName: speechService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                }

                // Skip forward
                Button {
                    speechService.skipForward()
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .padding(.vertical, 8)

            // Speed and settings
            HStack {
                // Speed control
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button {
                            speechService.changeRate(Float(rate))
                        } label: {
                            HStack {
                                Text("\(rate, specifier: "%.2f")x")
                                if abs(speechService.currentRate - Float(rate)) < 0.01 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "gauge")
                        Text("\(speechService.currentRate, specifier: "%.2f")x")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }

                Spacer()

                // Font size
                Menu {
                    ForEach([14, 16, 18, 20, 24, 28], id: \.self) { size in
                        Button {
                            fontSize = CGFloat(size)
                        } label: {
                            HStack {
                                Text("\(size) pt")
                                if fontSize == CGFloat(size) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "textformat.size")
                        Text("\(Int(fontSize)) pt")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }

                Spacer()

                // Stop button
                Button {
                    speechService.stop()
                } label: {
                    Image(systemName: "stop.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

#Preview {
    TextReaderView(
        url: "https://example.com/article",
        title: "Example Article"
    )
}
