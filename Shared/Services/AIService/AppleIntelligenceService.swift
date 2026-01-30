//
//  AppleIntelligenceService.swift
//  RSS RAIder
//

import Foundation
import NaturalLanguage
#if canImport(Translation)
import Translation
#endif

@available(iOS 18.0, macOS 15.0, *)
class AppleIntelligenceService: AIService, AIQuestionAnswering {

    private struct DuplicateCandidate {
        let item: NewsItem
        let normalizedTitle: String
        let titleTokens: Set<String>
        let summaryTokens: Set<String>
        let allTokens: Set<String>
    }
    
    func scoreQuality(newsItem: NewsItem) async throws -> QualityScore {
        // Use Apple Intelligence APIs for quality scoring
        // Note: This is a simplified implementation
        // In production, you'd use Writing Tools API or similar

        // Simulate Apple Intelligence analysis
        // In real implementation, use Writing Tools or Foundation LLM APIs
        let score = analyzeContent(newsItem)
        
        return QualityScore(
            overallScore: score.score,
            isClickbait: score.isClickbait,
            isSpam: score.isSpam,
            isAdvertisement: score.isAd,
            contentQuality: score.quality,
            reasoning: score.reasoning
        )
    }
    
    func detectDuplicates(newsItems: [NewsItem]) async throws -> [DuplicateGroup] {
        let stopwords = Set([
            "de", "la", "el", "los", "las", "un", "una", "unos", "unas", "del", "al", "y", "e", "o", "u",
            "para", "por", "con", "sin", "en", "a", "que", "se", "es", "su", "sus", "como", "mas", "pero",
            "the", "and", "or", "of", "to", "in", "on", "for", "is", "are", "was", "were", "be"
        ])

        let candidates: [DuplicateCandidate] = newsItems.map { item in
            let normalizedTitle = normalize(item.aiTitle)
            let normalizedSummary = normalize(item.aiSummary)
            let titleTokens = Set(tokenize(normalizedTitle, stopwords: stopwords))
            let summaryTokens = Set(tokenize(normalizedSummary, stopwords: stopwords))
            let allTokens = titleTokens.union(summaryTokens)
            return DuplicateCandidate(
                item: item,
                normalizedTitle: normalizedTitle,
                titleTokens: titleTokens,
                summaryTokens: summaryTokens,
                allTokens: allTokens
            )
        }

        var assigned = Array(repeating: false, count: candidates.count)
        var groups: [DuplicateGroup] = []

        for i in candidates.indices {
            if assigned[i] { continue }

            var groupIndices: [Int] = [i]
            assigned[i] = true

            for j in candidates.indices where j > i {
                if assigned[j] { continue }

                if isDuplicate(candidates[i], candidates[j]) {
                    groupIndices.append(j)
                    assigned[j] = true
                } else {
                    let matchesAny = groupIndices.contains { isDuplicate(candidates[$0], candidates[j]) }
                    if matchesAny {
                        groupIndices.append(j)
                        assigned[j] = true
                    }
                }
            }

            if groupIndices.count > 1 {
                let groupItems = groupIndices.map { candidates[$0].item }
                groups.append(DuplicateGroup(id: UUID(), newsItems: groupItems))
            }
        }

        return groups
    }
    
    func classifyIntoSmartFolders(newsItem: NewsItem, smartFolders: [SmartFolder]) async throws -> [UUID] {
        var matchingFolders: [UUID] = []

        let normalizedTitle = normalize(newsItem.aiTitle)
        let normalizedSummary = normalize(newsItem.aiSummary)
        let content = "\(normalizedTitle) \(normalizedSummary)"

        let stopwords = Set([
            "noticia", "noticias", "news", "sobre", "about", "latest", "update", "updates",
            "de", "la", "el", "los", "las", "un", "una", "unos", "unas", "del", "al", "y", "e", "o", "u",
            "para", "por", "con", "sin", "en", "a", "the", "and", "or", "of"
        ])

        let breakingKeywords = [
            "breaking", "ultima hora", "urgent", "urgente", "alerta", "en desarrollo", "developing",
            "primicia", "exclusiva", "ultimo minuto"
        ]

        let importanceKeywords = [
            "importante", "historico", "crisis", "guerra", "conflicto", "eleccion", "elecciones",
            "acuerdo", "ley", "gobierno", "economia", "mercados", "fallece", "muere", "dimite", "renuncia"
        ]

        let contentTokens = Set(tokenize(content, stopwords: stopwords))

        let recencyHours: Double? = {
            guard let pubDate = newsItem.pubDate else { return nil }
            return Date().timeIntervalSince(pubDate) / 3600
        }()

        let isBreakingCandidate = containsAny(content, keywords: breakingKeywords) || containsAny(normalizedTitle, keywords: breakingKeywords)
        let isImportantCandidate = containsAny(content, keywords: importanceKeywords) || containsAny(normalizedTitle, keywords: importanceKeywords)
        let isRecent = (recencyHours ?? 999) <= 24
        let isVeryRecent = (recencyHours ?? 999) <= 12

        for folder in smartFolders where folder.isEnabled {
            let folderText = normalize("\(folder.name) \(folder.description)")

            let isHotFolder = containsAny(folderText, keywords: breakingKeywords)
                || folderText.contains("hot")
                || folderText.contains("tendencia")

            if isHotFolder {
                let isHotNews = (isBreakingCandidate && (isRecent || recencyHours == nil))
                    || (isImportantCandidate && (isVeryRecent || recencyHours == nil))
                if isHotNews {
                    matchingFolders.append(folder.id)
                }
                continue
            }

            let nameTokens = tokenize(normalize(folder.name), stopwords: stopwords)
            let descriptionTokens = tokenize(normalize(folder.description), stopwords: stopwords)
            let tokens = Array(Set(nameTokens + descriptionTokens))
            let phrases = extractPhrases(from: folder.description)

            if tokens.isEmpty && phrases.isEmpty {
                continue
            }

            var totalWeight = 0.0
            var matchedWeight = 0.0
            var matchedNameOrPhrase = false
            var matchedTokensCount = 0

            for token in tokens {
                let inName = nameTokens.contains(token)
                let weight = inName ? 1.6 : 1.0
                totalWeight += weight
                if matchesToken(token, contentTokens: contentTokens, content: content) {
                    matchedWeight += weight
                    matchedTokensCount += 1
                    if inName {
                        matchedNameOrPhrase = true
                    }
                }
            }

            for phrase in phrases {
                let weight = 2.0
                totalWeight += weight
                if content.contains(phrase) {
                    matchedWeight += weight
                    matchedTokensCount += 1
                    matchedNameOrPhrase = true
                }
            }

            let ratio = totalWeight > 0 ? matchedWeight / totalWeight : 0
            let minimumRatio: Double
            if tokens.count <= 2 {
                minimumRatio = 0.25
            } else if tokens.count <= 6 {
                minimumRatio = 0.3
            } else {
                minimumRatio = 0.35
            }

            let minimumMatches = tokens.count <= 6 ? 1 : 2
            let hasEnoughMatches = matchedNameOrPhrase || matchedTokensCount >= minimumMatches

            if hasEnoughMatches && ratio >= minimumRatio && matchedWeight >= 0.8 {
                matchingFolders.append(folder.id)
            }
        }

        return matchingFolders
    }

    /// Assigns smart tags to a news item based on tag descriptions
    /// Tags are processed in priority order (highest priority first)
    func assignTags(newsItem: NewsItem, tags: [SmartTag]) async throws -> [UUID] {
        var matchingTags: [UUID] = []

        let normalizedTitle = normalize(newsItem.aiTitle)
        let normalizedSummary = normalize(newsItem.aiSummary)
        let content = "\(normalizedTitle) \(normalizedSummary)"

        let stopwords = Set([
            "noticia", "noticias", "news", "sobre", "about", "latest", "update", "updates",
            "de", "la", "el", "los", "las", "un", "una", "unos", "unas", "del", "al", "y", "e", "o", "u",
            "para", "por", "con", "sin", "en", "a", "the", "and", "or", "of"
        ])

        let contentTokens = Set(tokenize(content, stopwords: stopwords))

        // Sort tags by priority (highest first)
        let sortedTags = tags.filter { $0.isEnabled }.sorted { $0.priority > $1.priority }

        for tag in sortedTags {
            let nameTokens = tokenize(normalize(tag.name), stopwords: stopwords)
            let descriptionTokens = tokenize(normalize(tag.description), stopwords: stopwords)
            let tokens = Array(Set(nameTokens + descriptionTokens))
            let phrases = extractPhrases(from: tag.description)

            if tokens.isEmpty && phrases.isEmpty {
                continue
            }

            var totalWeight = 0.0
            var matchedWeight = 0.0
            var matchedNameOrPhrase = false
            var matchedTokensCount = 0

            // Weight tokens from tag name higher
            for token in tokens {
                let inName = nameTokens.contains(token)
                let weight = inName ? 1.8 : 1.0
                totalWeight += weight
                if matchesToken(token, contentTokens: contentTokens, content: content) {
                    matchedWeight += weight
                    matchedTokensCount += 1
                    if inName {
                        matchedNameOrPhrase = true
                    }
                }
            }

            // Weight phrases even higher
            for phrase in phrases {
                let weight = 2.5
                totalWeight += weight
                if content.contains(phrase) {
                    matchedWeight += weight
                    matchedTokensCount += 1
                    matchedNameOrPhrase = true
                }
            }

            let ratio = totalWeight > 0 ? matchedWeight / totalWeight : 0

            // Dynamic threshold based on token count
            let minimumRatio: Double
            if tokens.count <= 2 {
                minimumRatio = 0.2
            } else if tokens.count <= 4 {
                minimumRatio = 0.25
            } else if tokens.count <= 8 {
                minimumRatio = 0.3
            } else {
                minimumRatio = 0.35
            }

            let minimumMatches = tokens.count <= 4 ? 1 : 2
            let hasEnoughMatches = matchedNameOrPhrase || matchedTokensCount >= minimumMatches

            if hasEnoughMatches && ratio >= minimumRatio && matchedWeight >= 0.6 {
                matchingTags.append(tag.id)
            }
        }

        return matchingTags
    }

    func answerQuestion(question: String, context: String) async throws -> String {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        let cleanedContext = normalizeWhitespace(context)
        guard !cleanedContext.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        let maxChars = 20000
        let limitedContext = cleanedContext.count > maxChars
            ? String(cleanedContext.prefix(maxChars))
            : cleanedContext

        let answer = extractAnswer(question: trimmedQuestion, context: limitedContext)
        return answer.isEmpty ? "No se encontraron coincidencias. Prueba con otras palabras." : answer
    }
    
    // MARK: - Helper Methods

    private func extractAnswer(question: String, context: String) -> String {
        let stopwords = Set([
            "de", "la", "el", "los", "las", "un", "una", "unos", "unas", "del", "al", "y", "e", "o", "u",
            "para", "por", "con", "sin", "en", "a", "que", "se", "es", "su", "sus", "como", "mas", "pero",
            "sobre", "entre", "desde", "hasta", "muy", "ya", "asi", "porque", "cuando", "donde", "quien",
            "the", "and", "or", "of", "to", "in", "on", "for", "is", "are", "was", "were", "be", "with",
            "this", "that", "these", "those", "from", "as", "by"
        ])

        let normalizedQuestion = normalize(question)
        let questionTokens = Set(tokenize(normalizedQuestion, stopwords: stopwords))
        guard !questionTokens.isEmpty else {
            return "Introduce una pregunta mas concreta."
        }

        let sentences = splitIntoSentences(context)
        guard !sentences.isEmpty else {
            return "No hay texto disponible para analizar."
        }

        var scored: [(index: Int, sentence: String, score: Double)] = []

        for (index, sentence) in sentences.enumerated() {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count > 20 else { continue }

            let normalizedSentence = normalize(trimmed)
            let sentenceTokens = Set(tokenize(normalizedSentence, stopwords: stopwords))
            guard !sentenceTokens.isEmpty else { continue }

            var overlap = 0
            for token in questionTokens {
                if sentenceTokens.contains(token) || matchesToken(token, contentTokens: sentenceTokens, content: normalizedSentence) {
                    overlap += 1
                }
            }

            guard overlap > 0 else { continue }

            var score = Double(overlap) * 3.0
            let length = trimmed.count
            if length < 40 {
                score -= 1.5
            } else if length > 320 {
                score -= 1.0
            } else {
                score += 0.6
            }

            let positionBonus = 1.0 - (Double(index) / Double(max(sentences.count, 1)))
            score += positionBonus * 0.4

            scored.append((index: index, sentence: trimmed, score: score))
        }

        guard !scored.isEmpty else {
            return "No se encontraron coincidencias. Prueba con otras palabras."
        }

        let top = scored.sorted { $0.score > $1.score }
            .prefix(4)
            .sorted { $0.index < $1.index }

        return top.map { $0.sentence }.joined(separator: " ")
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func analyzeContent(_ newsItem: NewsItem) -> (score: Int, isClickbait: Bool, isSpam: Bool, isAd: Bool, quality: QualityScore.ContentQuality, reasoning: String) {
        let title = newsItem.aiTitle
        let summary = newsItem.aiSummary
        let normalizedTitle = normalize(title)
        let normalizedSummary = normalize(summary)
        let content = "\(normalizedTitle) \(normalizedSummary)"

        var score = 55
        var isClickbait = false
        var isSpam = false
        var isAd = false
        var reasons: [String] = []

        let breakingKeywords = [
            "breaking", "ultima hora", "urgent", "urgente", "alerta", "en desarrollo", "developing",
            "primicia", "exclusiva", "ultimo minuto"
        ]

        let importanceKeywords = [
            "importante", "historico", "crisis", "guerra", "conflicto", "eleccion", "elecciones",
            "acuerdo", "ley", "gobierno", "economia", "mercados", "fallece", "muere", "dimite", "renuncia"
        ]

        let qualityKeywords = [
            "investigacion", "entrevista", "informe", "reportaje", "analisis", "contexto",
            "datos", "estadisticas", "segun", "declarado", "declararon", "dijo", "fuentes"
        ]

        let lifeHackKeywords = [
            "life hack", "lifehack", "truco", "trucos", "consejo", "consejos", "tips", "hack",
            "how to", "como hacer", "guia", "tutorial", "diy", "hazlo tu mismo"
        ]

        let softNewsKeywords = [
            "lifestyle", "estilo de vida", "moda", "tendencia", "decoracion", "interiorismo",
            "diseno", "hotel", "hoteles", "habitacion", "habitaciones", "viaje", "viajes",
            "turismo", "gastronomia", "receta", "recetas", "celebridad", "entretenimiento"
        ]

        if containsAny(content, keywords: breakingKeywords) {
            score += 14
            reasons.append("senal de ultima hora")
        }

        if containsAny(content, keywords: importanceKeywords) {
            score += 10
            reasons.append("tema de alto impacto")
        }

        if containsAny(content, keywords: qualityKeywords) {
            score += 6
            reasons.append("senal de reportaje o analisis")
        }

        if containsAny(content, keywords: lifeHackKeywords) {
            score -= 12
            reasons.append("contenido tipo trucos o consejos")
        }

        if containsAny(content, keywords: softNewsKeywords) && !containsAny(content, keywords: importanceKeywords) {
            score -= 12
            reasons.append("tema de bajo impacto")
        }

        if let pubDate = newsItem.pubDate {
            let hours = Date().timeIntervalSince(pubDate) / 3600
            if hours <= 6 {
                score += 12
                reasons.append("muy reciente")
            } else if hours <= 24 {
                score += 8
                reasons.append("reciente")
            } else if hours <= 72 {
                score += 4
            }
        }

        let summaryLength = normalizedSummary.count
        if summaryLength > 400 {
            score += 10
            reasons.append("resumen detallado")
        } else if summaryLength > 200 {
            score += 6
            reasons.append("resumen suficiente")
        } else if summaryLength < 80 {
            score -= 8
            reasons.append("resumen muy corto")
        }

        // Clickbait detection
        let clickbaitPhrases = [
            "no vas a creer", "no creerias", "increible", "impactante", "sorprendente", "escandalo",
            "lo que paso", "secreto", "trucos", "truco"
        ]
        if containsAny(normalizedTitle, keywords: clickbaitPhrases) || excessivePunctuation(title) || highUppercaseRatio(title) {
            isClickbait = true
            score -= 25
        }

        // Spam detection
        let spamPhrases = ["gratis", "haz clic", "compra ahora", "oferta", "descuento", "gana dinero", "limitado", "actua ahora"]
        if containsAny(content, keywords: spamPhrases) {
            isSpam = true
            score -= 40
        }

        // Ad detection
        let adPhrases = ["patrocinado", "publicidad", "promocionado", "sponsored", "affiliate", "afiliado"]
        if containsAny(content, keywords: adPhrases) {
            isAd = true
            score -= 20
        }

        score = max(0, min(100, score))

        let quality: QualityScore.ContentQuality
        if score >= 80 {
            quality = .high
        } else if score >= 50 {
            quality = .medium
        } else {
            quality = .low
        }

        let reasoning = reasons.isEmpty
            ? "Puntaje base con ajustes por senales negativas."
            : reasons.map { "- \($0)" }.joined(separator: "\n")

        return (score, isClickbait, isSpam, isAd, quality, reasoning)
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().folding(options: .diacriticInsensitive, locale: .current)
    }

    private func tokenize(_ text: String, stopwords: Set<String>) -> [String] {
        let parts = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return parts.filter { $0.count > 2 && !stopwords.contains($0) }
    }

    private func extractPhrases(from description: String) -> [String] {
        description
            .split(separator: ",")
            .map { normalize($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0.split(separator: " ").count > 1 }
    }

    private func matchesToken(_ token: String, contentTokens: Set<String>, content: String) -> Bool {
        if contentTokens.contains(token) {
            return true
        }

        for synonym in synonyms(for: token) {
            if contentTokens.contains(synonym) || content.contains(synonym) {
                return true
            }
        }

        return false
    }

    private func synonyms(for token: String) -> [String] {
        let base = normalize(token)
        let mapping: [String: [String]] = [
            "politics": ["politica", "politico", "gobierno", "eleccion", "elecciones", "parlamento", "congreso", "senado"],
            "political": ["politica", "politico", "gobierno", "eleccion"],
            "politica": ["politics", "political", "gobierno", "eleccion"],
            "government": ["gobierno", "estado", "administracion", "ministerio"],
            "gobierno": ["government", "estado", "administracion", "ministerio"],
            "economy": ["economia", "finanzas", "mercados", "bolsa", "negocios", "empresa", "empresas"],
            "economia": ["economy", "finanzas", "mercados", "bolsa", "negocios", "empresa", "empresas"],
            "business": ["negocios", "empresa", "empresas", "finanzas"],
            "sports": ["deportes", "futbol", "baloncesto", "tenis", "formula"],
            "deportes": ["sports", "futbol", "baloncesto", "tenis", "formula"],
            "technology": ["tecnologia", "software", "hardware", "inteligencia", "artificial", "programacion", "gadgets"],
            "tecnologia": ["technology", "software", "hardware", "inteligencia", "artificial", "programacion", "gadgets"],
            "science": ["ciencia", "investigacion", "estudio", "estudios", "cientifico"],
            "ciencia": ["science", "investigacion", "estudio", "estudios", "cientifico"],
            "health": ["salud", "medicina", "hospital", "vacuna", "epidemia"],
            "salud": ["health", "medicina", "hospital", "vacuna", "epidemia"],
            "climate": ["clima", "cambio", "climatico", "medio", "ambiente"],
            "clima": ["climate", "cambio", "climatico", "medio", "ambiente"],
            "war": ["guerra", "conflicto", "ataque", "invasion"],
            "guerra": ["war", "conflicto", "ataque", "invasion"]
        ]

        var synonyms = mapping[base] ?? []

        if base.hasSuffix("s") && base.count > 3 {
            synonyms.append(String(base.dropLast()))
        }

        if base.hasSuffix("es") && base.count > 4 {
            synonyms.append(String(base.dropLast(2)))
        }

        return Array(Set(synonyms))
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }

    private func excessivePunctuation(_ title: String) -> Bool {
        title.contains("!!") || title.contains("??") || title.contains("!?")
    }

    private func highUppercaseRatio(_ title: String) -> Bool {
        let letters = title.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let uppercase = letters.filter { $0.isUppercase }
        return Double(uppercase.count) / Double(letters.count) > 0.45
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let words1 = Set(str1.split(separator: " "))
        let words2 = Set(str2.split(separator: " "))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return Double(intersection.count) / Double(union.count)
    }

    private func jaccardSimilarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 0 }
        let intersection = lhs.intersection(rhs)
        let union = lhs.union(rhs)
        return Double(intersection.count) / Double(union.count)
    }

    private func isDuplicate(_ lhs: DuplicateCandidate, _ rhs: DuplicateCandidate) -> Bool {
        if lhs.item.feedID == rhs.item.feedID {
            return false
        }

        let titleOverlap = calculateSimilarity(lhs.normalizedTitle, rhs.normalizedTitle)
        let titleJaccard = jaccardSimilarity(lhs.titleTokens, rhs.titleTokens)
        let allJaccard = jaccardSimilarity(lhs.allTokens, rhs.allTokens)
        let summaryJaccard = jaccardSimilarity(lhs.summaryTokens, rhs.summaryTokens)

        if lhs.normalizedTitle == rhs.normalizedTitle {
            return true
        }

        let containsTitle = lhs.normalizedTitle.contains(rhs.normalizedTitle) || rhs.normalizedTitle.contains(lhs.normalizedTitle)

        let maxTitleSimilarity = max(titleOverlap, titleJaccard)
        var score = maxTitleSimilarity * 0.6
        score += allJaccard * 0.25
        score += summaryJaccard * 0.15
        if containsTitle {
            score += 0.1
        }

        var threshold = 0.6
        if let lhsDate = lhs.item.pubDate, let rhsDate = rhs.item.pubDate {
            let hours = abs(lhsDate.timeIntervalSince(rhsDate)) / 3600
            if hours > 72 {
                threshold = 0.65
            }
            if hours > 168 {
                threshold = 0.72
            }
        }

        if maxTitleSimilarity >= 0.65 {
            return true
        }

        if maxTitleSimilarity >= 0.45 && (allJaccard >= 0.3 || summaryJaccard >= 0.25 || containsTitle) {
            return true
        }

        let coreMatch = maxTitleSimilarity >= 0.35 || allJaccard >= 0.35
        return coreMatch && score >= threshold
    }
}
