import Foundation

struct GitIdentity: Codable, Equatable, Sendable {
    var name: String
    var email: String

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}

struct GitRemote: Identifiable, Codable, Hashable, Sendable {
    var name: String
    var url: String
    var id: String { name }
}

struct GitRepository: Codable, Equatable, Sendable {
    var path: URL
    var branch: String
    var head: String?
    var isDirty: Bool
    var remotes: [GitRemote]
}

struct GitResult: Equatable, Sendable {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

enum GitError: LocalizedError, Equatable, Sendable {
    case gitNotInstalled
    case notRepository
    case invalidHEAD
    case dirtyWorkingTree
    case identityMissing
    case writePermissionDenied
    case commandFailed(arguments: [String], message: String, code: Int32)
    case remoteUnavailable(String)
    case cancelled
    case restoreUnavailable

    var errorDescription: String? {
        switch self {
        case .gitNotInstalled: "Git is not installed or could not be found."
        case .notRepository: "The selected folder is not a Git repository."
        case .invalidHEAD: "The repository has no valid HEAD. Create an initial commit first."
        case .dirtyWorkingTree: "The repository has uncommitted changes. Commit or stash them before generation."
        case .identityMissing: "Git could not create commits because no valid author name and email are configured."
        case .writePermissionDenied: "The repository is not writable."
        case let .commandFailed(_, message, code): "Git failed (exit \(code)): \(message)"
        case let .remoteUnavailable(message): "The Git remote is unavailable: \(message)"
        case .cancelled: "Commit generation was cancelled safely."
        case .restoreUnavailable: "The recorded restore point is no longer available."
        }
    }
}

enum ContributionError: LocalizedError, Equatable, Sendable {
    case invalidDateRange
    case tooManyCommits(Int)
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .invalidDateRange: "Choose a valid date range of no more than five years."
        case let .tooManyCommits(count): "The plan contains \(count) commits, which exceeds the 100,000 commit safety limit."
        case let .invalidConfiguration(message): message
        }
    }
}
