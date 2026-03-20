import Foundation

@MainActor
final class InsertionCompatibilityStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadAttempts() -> [InsertionAttempt] {
        let url = storeURL()

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([InsertionAttempt].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            return []
        }
    }

    func append(_ attempt: InsertionAttempt) {
        var attempts = loadAttempts()
        attempts.insert(attempt, at: 0)
        saveAttempts(attempts)
    }

    func preferredMethod(for bundleIdentifier: String, preferStableDelivery: Bool) -> InsertionMethod? {
        guard preferStableDelivery, !bundleIdentifier.isEmpty else {
            return nil
        }

        return loadAttempts()
            .first(where: { $0.bundleIdentifier == bundleIdentifier && $0.success })?
            .method
    }

    private func saveAttempts(_ attempts: [InsertionAttempt]) {
        let url = storeURL()

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(Array(attempts.prefix(120)))
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist insertion attempts: \(error)")
        }
    }

    private func storeURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return appSupport
            .appendingPathComponent("AsterTypeless", isDirectory: true)
            .appendingPathComponent("insertion-compatibility.json")
    }
}
