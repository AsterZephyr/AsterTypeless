import Foundation

struct TranscriptProcessingResult {
    var rawText: String
    var normalizedText: String
    var appliedLexicon: [String]
}

@MainActor
final class TranscriptPostProcessor {
    func process(
        rawText: String,
        context: VoiceFlowContext,
        lexicon: [LexiconEntry]
    ) -> TranscriptProcessingResult {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TranscriptProcessingResult(rawText: rawText, normalizedText: "", appliedLexicon: [])
        }

        var text = normalizeWhitespace(trimmed)
        text = foldAcronyms(in: text)
        text = mergeJoinedTokens(in: text)
        let lexiconResult = applyLexicon(lexicon, to: text)
        text = lexiconResult.text
        text = normalizeCaseAndPunctuation(text)
        text = cleanupForApp(text, context: context)

        return TranscriptProcessingResult(
            rawText: rawText,
            normalizedText: text,
            appliedLexicon: lexiconResult.applied
        )
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func foldAcronyms(in text: String) -> String {
        let pattern = #"\b(?:[A-Za-z]\s){1,}[A-Za-z]\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var mutable = text
        for match in matches {
            guard let range = Range(match.range, in: mutable) else { continue }
            let folded = mutable[range].replacingOccurrences(of: " ", with: "").uppercased()
            mutable.replaceSubrange(range, with: folded)
        }
        return mutable
    }

    private func mergeJoinedTokens(in text: String) -> String {
        text
            .replacingOccurrences(of: "Git Hub", with: "GitHub")
            .replacingOccurrences(of: "VS Code", with: "VS Code")
            .replacingOccurrences(of: "Type Script", with: "TypeScript")
            .replacingOccurrences(of: "Java Script", with: "JavaScript")
    }

    private func applyLexicon(_ lexicon: [LexiconEntry], to text: String) -> (text: String, applied: [String]) {
        var updated = text
        var applied: [String] = []

        for entry in lexicon {
            for variant in entry.variants.sorted(by: { $0.count > $1.count }) where !variant.isEmpty {
                if updated.localizedCaseInsensitiveContains(variant) {
                    updated = updated.replacingOccurrences(
                        of: variant,
                        with: entry.canonical,
                        options: [.caseInsensitive]
                    )
                    applied.append(entry.canonical)
                }
            }
        }

        return (updated, Array(Set(applied)).sorted())
    }

    private func normalizeCaseAndPunctuation(_ text: String) -> String {
        text
            .replacingOccurrences(of: " ，", with: "，")
            .replacingOccurrences(of: " 。", with: "。")
            .replacingOccurrences(of: " !", with: "!")
            .replacingOccurrences(of: " ?", with: "?")
            .replacingOccurrences(of: "： ", with: "：")
    }

    private func cleanupForApp(_ text: String, context: VoiceFlowContext) -> String {
        let bundle = context.bundleIdentifier.lowercased()
        if bundle.contains("cursor") || bundle.contains("vscode") || bundle.contains("xcode") {
            return text
                .replacingOccurrences(of: "（", with: "(")
                .replacingOccurrences(of: "）", with: ")")
                .replacingOccurrences(of: "，", with: ", ")
        }

        if bundle.contains("slack") || bundle.contains("wechat") || bundle.contains("feishu") || bundle.contains("lark") {
            return text
        }

        return text
    }
}
