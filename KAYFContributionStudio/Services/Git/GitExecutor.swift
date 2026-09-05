import Foundation

protocol GitExecuting: Sendable {
    func run(arguments: [String], directory: URL, environment: [String: String]) async throws -> GitResult
}

actor GitExecutor: GitExecuting {
    func run(arguments: [String], directory: URL, environment: [String: String] = [:]) async throws -> GitResult {
        try Task.checkCancellation()
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = directory
        process.standardOutput = standardOutput
        process.standardError = standardError
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, supplied in supplied }

        do {
            try process.run()
        } catch {
            throw GitError.gitNotInstalled
        }
        process.waitUntilExit()
        let stdout = String(decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: standardError.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return GitResult(stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                         stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                         exitCode: process.terminationStatus)
    }
}

struct RecordingGitExecutor: GitExecuting {
    let handler: @Sendable ([String], URL, [String: String]) async throws -> GitResult
    func run(arguments: [String], directory: URL, environment: [String: String]) async throws -> GitResult {
        try await handler(arguments, directory, environment)
    }
}
