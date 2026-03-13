import Foundation

@MainActor
final class TranscriptStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSessions() -> [DictationSession] {
        let url = storeURL()

        guard FileManager.default.fileExists(atPath: url.path) else {
            let seeded = DictationSession.sampleData.sorted { $0.createdAt > $1.createdAt }
            saveSessions(seeded)
            return seeded
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([DictationSession].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            return DictationSession.sampleData.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func append(_ session: DictationSession) {
        var sessions = loadSessions()
        sessions.insert(session, at: 0)
        saveSessions(sessions)
    }

    private func saveSessions(_ sessions: [DictationSession]) {
        let url = storeURL()

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(sessions)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist sessions: \(error)")
        }
    }

    private func storeURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return appSupport
            .appendingPathComponent("AsterTypeless", isDirectory: true)
            .appendingPathComponent("dictation-history.json")
    }
}
