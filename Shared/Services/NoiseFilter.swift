//
//  NoiseFilter.swift
//  RSS RAIder
//

import Foundation

struct NoiseFilterResult {
    let paragraphs: [String]
    let removedSections: [String]
}

struct NoiseFilter {
    func filter(_ paragraphs: [String]) -> NoiseFilterResult {
        var removed: Set<String> = []
        var cleaned: [String] = []

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let normalized = TextCleaner.normalizedForComparison(trimmed)

            if isNoiseParagraph(normalized) {
                if isSubscribePrompt(normalized) {
                    removed.insert("subscribe")
                } else if isRelatedPrompt(normalized) {
                    removed.insert("related")
                } else if isCookiePrompt(normalized) {
                    removed.insert("cookie_banner")
                } else if isSharePrompt(normalized) {
                    removed.insert("share")
                } else if isLoginPrompt(normalized) {
                    removed.insert("login")
                } else {
                    removed.insert("boilerplate")
                }
                continue
            }

            if trimmed.count < 30 && !containsSentencePunctuation(trimmed) {
                continue
            }

            cleaned.append(trimmed)
        }

        return NoiseFilterResult(paragraphs: cleaned, removedSections: Array(removed))
    }

    private func isNoiseParagraph(_ normalized: String) -> Bool {
        if normalized.isEmpty { return true }

        // Check if it's a social share button line
        if isSocialShareLine(normalized) { return true }

        let noisePhrases = [
            // Spanish
            "leer mas", "seguir leyendo", "leer tambien", "ver mas", "descubre mas",
            "suscribete", "suscripcion", "newsletter", "inicia sesion", "registrate",
            "acepta cookies", "aceptar cookies", "politica de cookies", "politica de privacidad",
            "compartir en", "compartelo en", "te puede interesar", "relacionado",
            "relacionados", "publicidad", "anuncio", "contenido patrocinado",
            "enviar por correo", "enviar por email", "copiar enlace", "imprimir",
            "mas noticias", "noticias relacionadas", "tambien te puede interesar",
            "articulos relacionados", "lee tambien", "quiza te interese",
            // English
            "read more", "continue reading", "subscribe", "sign in", "log in",
            "cookie policy", "privacy policy", "related", "recommended",
            "advertisement", "sponsored", "comments", "leave a comment",
            "share this", "share on", "email this", "print this", "copy link",
            "more stories", "you may also like", "recommended for you",
            "trending now", "most popular", "most read", "editor picks",
            "follow us on", "join our newsletter", "get updates",
            "click here to", "tap here to", "download our app",
            // Social platform names as share actions
            "share on facebook", "share on twitter", "share on linkedin",
            "share on whatsapp", "share on telegram", "share on pinterest",
            "post to facebook", "tweet this", "pin it", "share via email",
            "compartir en facebook", "compartir en twitter", "compartir en whatsapp",
            "compartir en linkedin", "compartir en telegram"
        ]

        return noisePhrases.contains { normalized.contains($0) }
    }

    /// Detects lines that are primarily social share button text
    private func isSocialShareLine(_ normalized: String) -> Bool {
        // Very short lines with just social network names
        let socialNetworks = ["facebook", "twitter", "x", "linkedin", "whatsapp", "telegram",
                              "pinterest", "reddit", "email", "mail", "imprimir", "print",
                              "copiar", "copy", "compartir", "share", "instagram", "tiktok",
                              "youtube", "flipboard", "pocket", "tumblr", "vk", "line"]

        // If line is very short and contains mostly social network name(s)
        let words = normalized.split(separator: " ").map { String($0) }
        if words.count <= 4 {
            let socialCount = words.filter { word in
                socialNetworks.contains(word)
            }.count
            if socialCount >= 1 && words.count <= 2 {
                return true
            }
            // Lines like "Share Facebook Twitter LinkedIn"
            if socialCount >= 2 {
                return true
            }
        }

        // Detect patterns like "0 Facebook Twitter 0 LinkedIn"
        let digitPattern = "^[0-9\\s]*(facebook|twitter|linkedin|whatsapp|email|compartir|share)[0-9\\s]*"
        if let regex = try? NSRegularExpression(pattern: digitPattern, options: .caseInsensitive) {
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            if regex.firstMatch(in: normalized, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }

    private func isSubscribePrompt(_ normalized: String) -> Bool {
        let phrases = ["suscrib", "subscribe", "newsletter", "suscripcion"]
        return phrases.contains { normalized.contains($0) }
    }

    private func isRelatedPrompt(_ normalized: String) -> Bool {
        let phrases = ["relacionado", "relacionados", "te puede interesar", "recommended", "related"]
        return phrases.contains { normalized.contains($0) }
    }

    private func isCookiePrompt(_ normalized: String) -> Bool {
        let phrases = ["cookie", "cookies", "consent", "gdpr"]
        return phrases.contains { normalized.contains($0) }
    }

    private func isSharePrompt(_ normalized: String) -> Bool {
        let phrases = ["compart", "share", "social"]
        return phrases.contains { normalized.contains($0) }
    }

    private func isLoginPrompt(_ normalized: String) -> Bool {
        let phrases = ["inicia sesion", "login", "log in", "sign in", "registrate"]
        return phrases.contains { normalized.contains($0) }
    }

    private func containsSentencePunctuation(_ text: String) -> Bool {
        text.contains(".") || text.contains("?") || text.contains("!")
    }
}
