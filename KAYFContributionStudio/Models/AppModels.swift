import Foundation

struct ContributionProject: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var repositoryPath: URL
    var defaultBranch: String
    var identity: GitIdentity
    var configuration: ContributionConfiguration
    var contributions: [ContributionDay]
    var commitPlan: CommitPlan?
    var generationSession: GenerationSession?
    var createdAt: Date = .now
    var updatedAt: Date = .now
}

struct HistoryEntry: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var pattern: String
    var commitCount: Int
    var repositoryPath: String
    var session: GenerationSession?
    var completed: Bool
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: Self { self }
}

struct AppSettings: Codable, Sendable {
    var appearance: AppAppearance = .system
    var theme: ContributionTheme = .github
    var customPalette: [ThemeColor] = ThemeColor.github
    var defaultRange: DateRangePreset = .twelveMonths
    var defaultPattern: ContributionPattern = .natural
    var messageStrategy: CommitMessageStrategy = .natural
    var customMessages: String = "chore: update activity"
    var timezoneIdentifier: String = TimeZone.current.identifier
    var defaultBranch: String = "main"
    var defaultName: String = ""
    var defaultEmail: String = ""
    var showGitCommands = false
    var verboseLogs = false
}

struct LogEntry: Identifiable, Codable, Sendable {
    enum Level: String, Codable, Sendable { case info, warning, error }
    var id: UUID = UUID()
    var timestamp: Date = .now
    var level: Level
    var message: String
}
