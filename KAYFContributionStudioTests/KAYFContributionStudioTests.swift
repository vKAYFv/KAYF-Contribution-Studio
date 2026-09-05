import Foundation
import XCTest
@testable import KAYFContributionStudio

final class ContributionGeneratorTests: XCTestCase {
    func testSeedIsDeterministic() throws {
        let configuration = fixedConfiguration()
        let generator = NaturalGenerator()
        XCTAssertEqual(try generator.generate(configuration: configuration), try generator.generate(configuration: configuration))
    }

    func testInclusiveDateRangeGeneration() throws {
        var configuration = fixedConfiguration()
        configuration.endDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: 9, to: configuration.startDate)!
        XCTAssertEqual(try BalancedGenerator().generate(configuration: configuration).count, 10)
    }

    func testWeekendFactorsCanDisableWeekendActivity() throws {
        var configuration = fixedConfiguration()
        configuration.activeDayFrequency = 1
        configuration.minimumCommits = 1
        configuration.maximumCommits = 1
        configuration.saturdayFactor = 0
        configuration.sundayFactor = 0
        let calendar = DateUtilities.calendar(timeZoneIdentifier: configuration.timeZoneIdentifier)
        let days = try WeekdayGenerator().generate(configuration: configuration)
        let weekends = days.filter { [1, 7].contains(calendar.component(.weekday, from: $0.date)) }
        XCTAssertTrue(weekends.allSatisfy { $0.count == 0 })
        XCTAssertTrue(days.contains { $0.count > 0 })
    }

    func testCommitCountsStayWithinLimits() throws {
        let configuration = fixedConfiguration()
        let days = try HeavyGenerator().generate(configuration: configuration)
        XCTAssertTrue(days.allSatisfy { $0.count == 0 || (configuration.minimumCommits...configuration.maximumCommits).contains($0.count) })
    }

    func testHeatmapBuckets() {
        XCTAssertEqual(HeatmapIntensity.level(for: 0, maximum: 12), 0)
        XCTAssertEqual(HeatmapIntensity.level(for: 1, maximum: 12), 1)
        XCTAssertEqual(HeatmapIntensity.level(for: 4, maximum: 12), 2)
        XCTAssertEqual(HeatmapIntensity.level(for: 7, maximum: 12), 3)
        XCTAssertEqual(HeatmapIntensity.level(for: 12, maximum: 12), 4)
    }

    func testTextArtProducesForegroundAndBackground() throws {
        var configuration = fixedConfiguration()
        configuration.endDate = Calendar.current.date(byAdding: .day, value: 90, to: configuration.startDate)!
        let blank = try ContributionGenerator().generate(configuration: configuration).map {
            ContributionDay(date: $0.date, count: 0)
        }
        let art = TextArtGenerator().apply(text: "K", to: blank, intensity: 8)
        XCTAssertTrue(art.contains { $0.count == 8 })
        XCTAssertTrue(art.contains { $0.count == 0 })
    }

    func testCommitPlanTimestampsAreOrderedAndInsideWorkHours() throws {
        var configuration = fixedConfiguration()
        configuration.startDate = configuration.endDate
        let day = ContributionDay(date: configuration.startDate, count: 20)
        let plan = try CommitPlanner().makePlan(days: [day], configuration: configuration, strategy: .natural)
        XCTAssertEqual(plan.commits.map(\.timestamp), plan.commits.map(\.timestamp).sorted())
        let calendar = DateUtilities.calendar(timeZoneIdentifier: configuration.timeZoneIdentifier)
        XCTAssertTrue(plan.commits.allSatisfy {
            (configuration.workdayStartHour...configuration.workdayEndHour).contains(calendar.component(.hour, from: $0.timestamp))
        })
    }

    func testPlannerIsDeterministicExceptCreationDate() throws {
        let configuration = fixedConfiguration()
        let days = try NaturalGenerator().generate(configuration: configuration)
        let first = try CommitPlanner().makePlan(days: days, configuration: configuration, strategy: .natural)
        let second = try CommitPlanner().makePlan(days: days, configuration: configuration, strategy: .natural)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.commits, second.commits)
    }

    func testTimezoneConversionIncludesRequestedOffset() {
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(DateUtilities.iso8601(date, timeZoneIdentifier: "Europe/Berlin"), "1970-01-01T01:00:00+01:00")
        XCTAssertEqual(DateUtilities.iso8601(date, timeZoneIdentifier: "UTC"), "1970-01-01T00:00:00Z")
    }

    private func fixedConfiguration() -> ContributionConfiguration {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var value = ContributionConfiguration.defaults(now: calendar.date(from: DateComponents(year: 2026, month: 3, day: 17))!, calendar: calendar)
        value.timeZoneIdentifier = "UTC"
        value.seed = 42
        return value
    }
}

final class GitServiceTests: XCTestCase {
    func testConfigureIdentityUsesArgumentArrays() async throws {
        let recorder = CommandRecorder()
        let executor = RecordingGitExecutor { arguments, _, _ in
            await recorder.append(arguments)
            return GitResult(stdout: "", stderr: "", exitCode: 0)
        }
        let service = GitService(executor: executor)
        try await service.configureIdentity(.init(name: "Kayf Dev", email: "kayf@example.com"), at: URL(fileURLWithPath: "/tmp"))
        let commands = await recorder.commands
        XCTAssertEqual(commands, [
            ["config", "user.name", "Kayf Dev"],
            ["config", "user.email", "kayf@example.com"]
        ])
    }

    func testGeneratesRealDatedCommitsInTemporaryRepository() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "KAYFIntegration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = GitService()
        try await service.initializeRepository(at: directory, branch: "main")
        let identity = GitIdentity(name: "KAYF Test", email: "kayf-test@example.com")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2025, month: 2, day: 3))!
        var configuration = ContributionConfiguration.defaults(now: date, calendar: calendar)
        configuration.startDate = date
        configuration.endDate = date
        configuration.timeZoneIdentifier = "UTC"
        configuration.seed = 99
        let plan = try CommitPlanner().makePlan(days: [.init(date: date, count: 10)], configuration: configuration, strategy: .generic)

        let result = try await service.generate(
            repository: directory,
            projectName: "Integration Test",
            plan: plan,
            identity: identity,
            timeZoneIdentifier: "UTC",
            control: GenerationControl()
        ) { _, _ in }

        XCTAssertEqual(result.session.generatedCommitCount, 10)
        let count = try await runGit(["rev-list", "--count", "HEAD"], at: directory)
        XCTAssertEqual(count, "10")
        let dates = try await runGit(["log", "--format=%aI|%cI"], at: directory)
        XCTAssertEqual(dates.split(separator: "\n").count, 10)
        XCTAssertTrue(dates.split(separator: "\n").allSatisfy { line in
            let pair = line.split(separator: "|")
            return pair.count == 2 && pair[0] == pair[1] && pair[0].hasPrefix("2025-02-03T")
        })
    }

    func testCancellationRollsBackGeneratedBranch() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "KAYFCancel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = GitService()
        let identity = GitIdentity(name: "KAYF Test", email: "kayf-test@example.com")
        try await service.initializeRepository(at: directory, branch: "main")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2025, month: 2, day: 3))!
        var configuration = ContributionConfiguration.defaults(now: date, calendar: calendar)
        configuration.startDate = date
        configuration.endDate = date
        configuration.timeZoneIdentifier = "UTC"
        let initial = try CommitPlanner().makePlan(days: [.init(date: date, count: 1)], configuration: configuration, strategy: .generic)
        _ = try await service.generate(repository: directory, projectName: "Initial", plan: initial, identity: identity, timeZoneIdentifier: "UTC", control: GenerationControl()) { _, _ in }

        let plan = try CommitPlanner().makePlan(days: [.init(date: date, count: 10)], configuration: configuration, strategy: .generic)
        let control = GenerationControl()
        do {
            _ = try await service.generate(repository: directory, projectName: "Cancelled", plan: plan, identity: identity, timeZoneIdentifier: "UTC", control: control) { count, _ in
                if count == 3 { await control.cancel() }
            }
            XCTFail("Generation should have been cancelled")
        } catch let error as GitError {
            XCTAssertEqual(error, .cancelled)
        }
        let repository = try await service.inspectRepository(at: directory)
        XCTAssertEqual(repository.branch, "main")
        XCTAssertFalse(repository.isDirty)
        let count = try await runGit(["rev-list", "--count", "HEAD"], at: directory)
        let generatedBranches = try await runGit(["branch", "--list", "kayf/contributions-*"], at: directory)
        XCTAssertEqual(count, "1")
        XCTAssertFalse(generatedBranches.contains("kayf/contributions"))
    }

    private func runGit(_ arguments: [String], at directory: URL) async throws -> String {
        let result = try await GitExecutor().run(arguments: arguments, directory: directory, environment: [:])
        XCTAssertEqual(result.exitCode, 0, result.stderr)
        return result.stdout
    }
}

private actor CommandRecorder {
    private(set) var commands: [[String]] = []
    func append(_ command: [String]) { commands.append(command) }
}
