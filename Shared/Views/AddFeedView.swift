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
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var isValid = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre del feed", text: $feedName)
                        #if os(iOS)
                        .textContentType(.none)
                        #endif

                    TextField("URL del feed", text: $feedURL)
                        #if os(iOS)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        #endif
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

        let (valid, message) = await feedsViewModel.validateFeedURL(feedURL)

        isValid = valid
        validationMessage = message
        isValidating = false

        // Auto-fill name if empty and valid
        if valid && feedName.isEmpty {
            if let url = URL(string: feedURL) {
                feedName = url.host ?? "RSS Feed"
            }
        }
    }

    private func saveFeed() {
        let feed = RSSFeed(name: feedName, url: feedURL)
        feedsViewModel.addFeed(feed)
        dismiss()
    }
}

#Preview {
    AddFeedView(feedsViewModel: FeedsViewModel())
}
