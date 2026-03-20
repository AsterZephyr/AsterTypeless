import Foundation

struct LexiconEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var canonical: String
    var variants: [String]
    var locale: String
    var appBundlePattern: String
    var hitCount: Int
    var promotedAt: Date?
    var updatedAt: Date

    var isPromoted: Bool {
        promotedAt != nil
    }
}

@MainActor
final class LexiconStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("AsterTypeless", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("lexicon.json")
    }

    func load() -> [LexiconEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([LexiconEntry].self, from: data)) ?? []
    }

    func entries(for context: VoiceFlowContext) -> [LexiconEntry] {
        let bundle = context.bundleIdentifier.lowercased()
        return load().filter { entry in
            entry.locale == context.locale
                && (entry.appBundlePattern.isEmpty || bundle.contains(entry.appBundlePattern))
                && entry.isPromoted
        }
    }

    @discardableResult
    func learn(rawText: String, acceptedText: String, context: VoiceFlowContext) -> [LexiconEntry] {
        let candidates = LexiconLearner.extractCandidates(
            rawText: rawText,
            acceptedText: acceptedText,
            context: context
        )
        guard !candidates.isEmpty else { return [] }

        var existing = load()
        var learned: [LexiconEntry] = []

        for candidate in candidates {
            if let index = existing.firstIndex(where: {
                $0.canonical.caseInsensitiveCompare(candidate.canonical) == .orderedSame
                    && $0.locale == candidate.locale
                    && $0.appBundlePattern == candidate.appBundlePattern
            }) {
                var entry = existing[index]
                entry.hitCount += 1
                entry.updatedAt = .now
                entry.variants = Array(Set(entry.variants + candidate.variants)).sorted()
                if entry.hitCount >= 3, entry.promotedAt == nil {
                    entry.promotedAt = .now
                }
                existing[index] = entry
                learned.append(entry)
            } else {
                existing.append(candidate)
                learned.append(candidate)
            }
        }

        save(existing)
        return learned
    }

    func promptHint(for context: VoiceFlowContext) -> String? {
        let terms = entries(for: context)
            .prefix(8)
            .map(\.canonical)
        guard !terms.isEmpty else { return nil }
        return "请优先识别这些术语：\(terms.joined(separator: "、"))"
    }

    private func save(_ entries: [LexiconEntry]) {
        guard let data = try? encoder.encode(entries.sorted { $0.updatedAt > $1.updatedAt }) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

enum LexiconLearner {
    private struct CandidatePair: Hashable {
        var canonical: String
        var variant: String
    }

    static func extractCandidates(
        rawText: String,
        acceptedText: String,
        context: VoiceFlowContext
    ) -> [LexiconEntry] {
        let normalizedRaw = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAccepted = acceptedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedRaw.isEmpty, !normalizedAccepted.isEmpty, normalizedRaw != normalizedAccepted else {
            return []
        }

        let acronyms = acronymCandidates(rawText: normalizedRaw, acceptedText: normalizedAccepted)
        let tokenCandidates = zippedTokenCandidates(rawText: normalizedRaw, acceptedText: normalizedAccepted)

        let all = Array(Set(acronyms + tokenCandidates))
            .map { pair -> LexiconEntry in
                LexiconEntry(
                    canonical: pair.canonical,
                    variants: [pair.variant],
                    locale: context.locale,
                    appBundlePattern: context.bundleIdentifier.lowercased(),
                    hitCount: 1,
                    promotedAt: nil,
                    updatedAt: .now
                )
            }

        return all
    }

    private static func acronymCandidates(rawText: String, acceptedText: String) -> [CandidatePair] {
        let pattern = #"\b(?:[A-Za-z]\s){1,}[A-Za-z]\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let rawRange = NSRange(rawText.startIndex..., in: rawText)
        let matches = regex.matches(in: rawText, range: rawRange)

        return matches.compactMap { match in
            guard let range = Range(match.range, in: rawText) else { return nil }
            let variant = String(rawText[range])
            let canonical = variant.replacingOccurrences(of: " ", with: "")
            guard canonical.count >= 2, acceptedText.localizedCaseInsensitiveContains(canonical) else { return nil }
            return CandidatePair(canonical: canonical.uppercased(), variant: variant)
        }
    }

    private static func zippedTokenCandidates(rawText: String, acceptedText: String) -> [CandidatePair] {
        let rawTokens = tokenize(rawText)
        let acceptedTokens = tokenize(acceptedText)
        let pairs = zip(rawTokens, acceptedTokens)

        return pairs.compactMap { rawToken, acceptedToken in
            guard rawToken.caseInsensitiveCompare(acceptedToken) != .orderedSame else { return nil }
            guard acceptedToken.count >= 2 else { return nil }
            guard acceptedToken.rangeOfCharacter(from: .letters) != nil else { return nil }
            return CandidatePair(canonical: acceptedToken, variant: rawToken)
        }
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
    }
}
