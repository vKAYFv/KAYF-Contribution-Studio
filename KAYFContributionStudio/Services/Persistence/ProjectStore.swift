import Foundation

actor ProjectStore {
    private let root: URL
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KAYF Contribution Studio", directoryHint: .isDirectory)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadProject() throws -> ContributionProject? { try decode("project.json") }
    func saveProject(_ project: ContributionProject) throws { try encode(project, named: "project.json") }
    func loadSettings() throws -> AppSettings { try decode("settings.json") ?? AppSettings() }
    func saveSettings(_ settings: AppSettings) throws { try encode(settings, named: "settings.json") }
    func loadHistory() throws -> [HistoryEntry] { try decode("history.json") ?? [] }
    func saveHistory(_ history: [HistoryEntry]) throws { try encode(history, named: "history.json") }

    private func encode<T: Encodable>(_ value: T, named name: String) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try encoder.encode(value).write(to: root.appending(path: name), options: .atomic)
    }

    private func decode<T: Decodable>(_ name: String) throws -> T? {
        let url = root.appending(path: name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
