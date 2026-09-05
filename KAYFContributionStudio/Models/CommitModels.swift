import Foundation

enum PlannedCommitStatus: String, Codable, Sendable {
    case planned, generated, failed
}

struct PlannedCommit: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var date: Date
    var timestamp: Date
    var message: String
    var sequence: Int
    var status: PlannedCommitStatus
}

struct CommitPlan: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var commits: [PlannedCommit]

    var activeDays: Int { Set(commits.map(\.date)).count }
    var totalCommits: Int { commits.count }
}

enum CommitMessageStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case generic = "Generic"
    case natural = "Natural"
    case custom = "Custom"
    var id: Self { self }
}

struct GenerationSession: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var originalHEAD: String?
    var originalBranch: String
    var generatedBranch: String
    var generatedCommitCount: Int
    var startedAt: Date
    var completedAt: Date?
}

struct GenerationResult: Codable, Sendable {
    var session: GenerationSession
    var finalHEAD: String
}

struct DryRunReport: Sendable {
    var repositoryPath: String
    var branch: String
    var dateRange: ClosedRange<Date>
    var activeDays: Int
    var plannedCommits: Int
    var estimatedSeconds: Int
    var identity: GitIdentity
    var remote: GitRemote?
    var warnings: [String]
}
