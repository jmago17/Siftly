//
//  ImageCacheService.swift
//  RSS RAIder
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class ImageCacheService {
    static let shared = ImageCacheService()

    private var cache = NSCache<NSString, ImageWrapper>()
    private var loadingTasks: [String: Task<Image?, Never>] = [:]

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func cachedImage(for urlString: String) -> Image? {
        cache.object(forKey: urlString as NSString)?.image
    }

    func loadImage(from urlString: String) async -> Image? {
        // Check cache first
        if let cached = cache.object(forKey: urlString as NSString) {
            return cached.image
        }

        // Check if already loading
        if let existingTask = loadingTasks[urlString] {
            return await existingTask.value
        }

        // Start new loading task
        let task = Task<Image?, Never> {
            guard let url = URL(string: urlString) else { return nil }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                #if os(iOS)
                guard let uiImage = UIImage(data: data) else { return nil }
                let image = Image(uiImage: uiImage)
                #elseif os(macOS)
                guard let nsImage = NSImage(data: data) else { return nil }
                let image = Image(nsImage: nsImage)
                #endif

                let wrapper = ImageWrapper(image: image)
                cache.setObject(wrapper, forKey: urlString as NSString, cost: data.count)

                return image
            } catch {
                return nil
            }
        }

        loadingTasks[urlString] = task
        let result = await task.value
        loadingTasks.removeValue(forKey: urlString)

        return result
    }

    func prefetchImages(urlStrings: [String]) {
        let uniqueURLs = Set(urlStrings.compactMap { url in
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })

        for urlString in uniqueURLs {
            if cache.object(forKey: urlString as NSString) != nil { continue }
            if loadingTasks[urlString] != nil { continue }

            Task { [weak self] in
                _ = await self?.loadImage(from: urlString)
            }
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

private final class ImageWrapper {
    let image: Image

    init(image: Image) {
        self.image = image
    }
}

// MARK: - Cached Async Image View

struct CachedAsyncImage: View {
    let urlString: String?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 8

    @State private var image: Image?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(cornerRadius)
        .task(id: urlString) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let urlString = urlString else { return }

        // Check cache immediately
        if let cached = ImageCacheService.shared.cachedImage(for: urlString) {
            image = cached
            return
        }

        isLoading = true
        image = await ImageCacheService.shared.loadImage(from: urlString)
        isLoading = false
    }
}
