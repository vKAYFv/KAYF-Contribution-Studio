import Foundation

actor GitService {
    private let executor: any GitExecuting

    init(executor: any GitExecuting = GitExecutor()) {
        self.executor = executor
    }

    func detectGit() async -> Bool {
        guard let result = try? await executor.run(arguments: ["--version"], directory: URL(fileURLWithPath: "/"), environment: [:]) else { return false }
        return result.exitCode == 0 && result.stdout.hasPrefix("git version")
    }

    func globalIdentity() async -> GitIdentity {
        let root = URL(fileURLWithPath: "/")
        let name = try? await checked(["config", "--global", "--get", "user.name"], at: root)
        let email = try? await checked(["config", "--global", "--get", "user.email"], at: root)
        return GitIdentity(name: name?.stdout ?? "", email: email?.stdout ?? "")
    }

    func initializeRepository(at url: URL, branch: String) async throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = try await checked(["init", "--initial-branch", branch], at: url)
    }

    func inspectRepository(at url: URL) async throws -> GitRepository {
        guard FileManager.default.fileExists(atPath: url.appending(path: ".git").path) else { throw GitError.notRepository }
        let branch = try await checked(["symbolic-ref", "--quiet", "--short", "HEAD"], at: url).stdout
        let headResult = try await executor.run(arguments: ["rev-parse", "--verify", "HEAD"], directory: url, environment: [:])
        let head = headResult.exitCode == 0 ? headResult.stdout : nil
        let status = try await checked(["status", "--porcelain"], at: url).stdout
        let remotes = try await listRemotes(at: url)
        return GitRepository(path: url, branch: branch, head: head, isDirty: !status.isEmpty, remotes: remotes)
    }

    func configuredIdentity(at url: URL, fallback: GitIdentity? = nil) async -> GitIdentity {
        let name = try? await checked(["config", "--get", "user.name"], at: url)
        let email = try? await checked(["config", "--get", "user.email"], at: url)
        return GitIdentity(name: name?.stdout ?? fallback?.name ?? "", email: email?.stdout ?? fallback?.email ?? "")
    }

    func configureIdentity(_ identity: GitIdentity, at url: URL) async throws {
        guard identity.isValid else { throw GitError.identityMissing }
        _ = try await checked(["config", "user.name", identity.name], at: url)
        _ = try await checked(["config", "user.email", identity.email], at: url)
    }

    func dryRun(repository url: URL, plan: CommitPlan, identity: GitIdentity) async throws -> DryRunReport {
        guard await detectGit() else { throw GitError.gitNotInstalled }
        let repository = try await inspectRepository(at: url)
        guard !repository.isDirty else { throw GitError.dirtyWorkingTree }
        guard identity.isValid else { throw GitError.identityMissing }
        guard FileManager.default.isWritableFile(atPath: url.path) else { throw GitError.writePermissionDenied }
        let available = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
        let required = Int64(max(5_000_000, plan.totalCommits * 2_048))
        if let available, available < required {
            throw ContributionError.invalidConfiguration("The repository volume does not have enough free space for this commit plan.")
        }
        guard let first = plan.commits.first?.date, let last = plan.commits.last?.date else {
            throw ContributionError.invalidConfiguration("The commit plan is empty.")
        }
        return DryRunReport(
            repositoryPath: url.path,
            branch: repository.branch,
            dateRange: first...last,
            activeDays: plan.activeDays,
            plannedCommits: plan.totalCommits,
            estimatedSeconds: max(1, Int((Double(plan.totalCommits) * 0.035).rounded())),
            identity: identity,
            remote: repository.remotes.first { $0.name == "origin" },
            warnings: repository.head == nil ? ["This empty repository has no initial HEAD; generated commits will begin its history."] : []
        )
    }

    func generate(
        repository url: URL,
        projectName: String,
        plan: CommitPlan,
        identity: GitIdentity,
        timeZoneIdentifier: String,
        control: GenerationControl,
        progress: @escaping @Sendable (Int, PlannedCommit) async -> Void
    ) async throws -> GenerationResult {
        let repository = try await inspectRepository(at: url)
        guard !repository.isDirty else { throw GitError.dirtyWorkingTree }
        guard identity.isValid else { throw GitError.identityMissing }
        try await configureIdentity(identity, at: url)

        let stamp = branchTimestamp(from: .now) + "-" + UUID().uuidString.prefix(6).lowercased()
        let generatedBranch = repository.head == nil ? repository.branch : "kayf/contributions-\(stamp)"
        if repository.head != nil {
            _ = try await checked(["switch", "-c", generatedBranch], at: url)
        }
        var session = GenerationSession(
            originalHEAD: repository.head,
            originalBranch: repository.branch,
            generatedBranch: generatedBranch,
            generatedCommitCount: 0,
            startedAt: .now
        )

        let activityDirectory = url.appending(path: ".kayf-contribution", directoryHint: .isDirectory)
        let activityFile = activityDirectory.appending(path: "activity.jsonl")
        try FileManager.default.createDirectory(at: activityDirectory, withIntermediateDirectories: true)

        do {
            for commit in plan.commits {
                try await control.checkpoint()
                try appendActivityLine(commit: commit, projectName: projectName, to: activityFile, timeZoneIdentifier: timeZoneIdentifier)
                _ = try await checked(["add", ".kayf-contribution/activity.jsonl"], at: url)
                let timestamp = DateUtilities.iso8601(commit.timestamp, timeZoneIdentifier: timeZoneIdentifier)
                _ = try await checked(
                    ["commit", "--quiet", "--message", commit.message],
                    at: url,
                    environment: [
                        "GIT_AUTHOR_DATE": timestamp,
                        "GIT_COMMITTER_DATE": timestamp,
                        "GIT_AUTHOR_NAME": identity.name,
                        "GIT_AUTHOR_EMAIL": identity.email,
                        "GIT_COMMITTER_NAME": identity.name,
                        "GIT_COMMITTER_EMAIL": identity.email
                    ]
                )
                session.generatedCommitCount += 1
                await progress(session.generatedCommitCount, commit)
            }
        } catch {
            await rollbackCancelledGeneration(repository: repository, generatedBranch: generatedBranch, at: url)
            throw error
        }
        session.completedAt = .now
        let head = try await checked(["rev-parse", "HEAD"], at: url).stdout
        return GenerationResult(session: session, finalHEAD: head)
    }

    func undo(session: GenerationSession, repository url: URL) async throws {
        let current = try await inspectRepository(at: url)
        guard !current.isDirty else { throw GitError.dirtyWorkingTree }
        if let originalHEAD = session.originalHEAD {
            _ = try await checked(["switch", session.originalBranch], at: url)
            _ = try await checked(["branch", "--delete", "--force", session.generatedBranch], at: url)
            let restored = try await checked(["rev-parse", "HEAD"], at: url).stdout
            guard restored == originalHEAD else { throw GitError.restoreUnavailable }
        } else {
            _ = try await checked(["update-ref", "-d", "refs/heads/\(session.originalBranch)"], at: url)
            try? FileManager.default.removeItem(at: url.appending(path: ".kayf-contribution"))
        }
    }

    func listRemotes(at url: URL) async throws -> [GitRemote] {
        let result = try await checked(["remote", "-v"], at: url)
        var seen = Set<String>()
        return result.stdout.split(separator: "\n").compactMap { line in
            let pieces = line.split(whereSeparator: \.isWhitespace)
            guard pieces.count >= 2 else { return nil }
            let name = String(pieces[0])
            guard seen.insert(name).inserted else { return nil }
            return GitRemote(name: name, url: String(pieces[1]))
        }
    }

    func setRemote(name: String = "origin", url remoteURL: String, at url: URL) async throws {
        let names = try await checked(["remote"], at: url).stdout.split(separator: "\n").map(String.init)
        let arguments = names.contains(name)
            ? ["remote", "set-url", name, remoteURL]
            : ["remote", "add", name, remoteURL]
        _ = try await checked(arguments, at: url)
    }

    func testRemote(_ name: String = "origin", at url: URL) async throws {
        _ = try await checked(["ls-remote", name], at: url)
    }

    func fetch(_ name: String = "origin", at url: URL) async throws {
        _ = try await checked(["fetch", name], at: url)
    }

    func push(remote: String = "origin", branch: String, at url: URL) async throws {
        _ = try await checked(["push", "--set-upstream", remote, branch], at: url)
    }

    private func checked(_ arguments: [String], at url: URL, environment: [String: String] = [:]) async throws -> GitResult {
        let result = try await executor.run(arguments: arguments, directory: url, environment: environment)
        guard result.exitCode == 0 else {
            throw GitError.commandFailed(arguments: arguments, message: result.stderr.isEmpty ? result.stdout : result.stderr, code: result.exitCode)
        }
        return result
    }

    private func appendActivityLine(commit: PlannedCommit, projectName: String, to url: URL, timeZoneIdentifier: String) throws {
        struct ActivityLine: Codable { var timestamp: String; var sequence: Int; var project: String }
        let line = ActivityLine(timestamp: DateUtilities.iso8601(commit.timestamp, timeZoneIdentifier: timeZoneIdentifier), sequence: commit.sequence, project: projectName)
        let data = try JSONEncoder().encode(line) + Data([0x0A])
        if !FileManager.default.fileExists(atPath: url.path) { _ = FileManager.default.createFile(atPath: url.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
    }

    private func rollbackCancelledGeneration(repository: GitRepository, generatedBranch: String, at url: URL) async {
        if repository.head != nil {
            _ = try? await checked(["reset", "--hard"], at: url)
            _ = try? await checked(["switch", repository.branch], at: url)
            _ = try? await checked(["branch", "--delete", "--force", generatedBranch], at: url)
        } else {
            try? FileManager.default.removeItem(at: url.appending(path: ".kayf-contribution"))
            _ = try? await checked(["read-tree", "--empty"], at: url)
            _ = try? await checked(["update-ref", "-d", "refs/heads/\(repository.branch)"], at: url)
        }
    }

    private func branchTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
