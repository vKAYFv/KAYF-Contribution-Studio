import Foundation

struct CommitPlanner: Sendable {
    static let naturalMessages = [
        "chore: update workspace",
        "docs: update notes",
        "refactor: cleanup",
        "build: refresh project state",
        "chore: maintenance",
        "docs: revise documentation",
        "style: formatting changes"
    ]

    func makePlan(
        days: [ContributionDay],
        configuration: ContributionConfiguration,
        strategy: CommitMessageStrategy,
        customMessages: [String] = []
    ) throws -> CommitPlan {
        let total = days.reduce(0) { $0 + max(0, $1.count) }
        guard total <= 100_000 else { throw ContributionError.tooManyCommits(total) }
        let calendar = DateUtilities.calendar(timeZoneIdentifier: configuration.timeZoneIdentifier)
        var random = SplitMix64(seed: configuration.seed ^ 0xA0761D6478BD642F)
        let messages = messagePool(strategy: strategy, custom: customMessages)
        var result: [PlannedCommit] = []
        result.reserveCapacity(total)
        var sequence = 1

        for day in days where day.count > 0 {
            let start = min(configuration.workdayStartHour, configuration.workdayEndHour)
            let end = max(configuration.workdayStartHour, configuration.workdayEndHour)
            let availableSeconds = max(1, (end - start) * 3_600)
            var offsets: [Int] = (0..<day.count).map { _ in
                configuration.randomizeTimes ? random.integer(in: 0...availableSeconds) : availableSeconds / 2
            }
            offsets.sort()

            for offset in offsets {
                let base = calendar.date(bySettingHour: start, minute: 0, second: 0, of: day.date) ?? day.date
                let timestamp = calendar.date(byAdding: .second, value: offset, to: base) ?? base
                let message = messages[random.integer(in: 0...(messages.count - 1))]
                result.append(.init(
                    id: deterministicUUID(random: &random),
                    date: calendar.startOfDay(for: day.date),
                    timestamp: timestamp,
                    message: message,
                    sequence: sequence,
                    status: .planned
                ))
                sequence += 1
            }
        }
        return CommitPlan(id: deterministicUUID(random: &random), createdAt: .now, commits: result)
    }

    private func messagePool(strategy: CommitMessageStrategy, custom: [String]) -> [String] {
        switch strategy {
        case .generic: ["chore: update activity"]
        case .natural: Self.naturalMessages
        case .custom:
            custom.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.isEmpty
                ? ["chore: update activity"]
                : custom.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
    }

    private func deterministicUUID(random: inout SplitMix64) -> UUID {
        let first = random.next()
        let second = random.next()
        return UUID(uuid: (
            UInt8(truncatingIfNeeded: first >> 56), UInt8(truncatingIfNeeded: first >> 48), UInt8(truncatingIfNeeded: first >> 40), UInt8(truncatingIfNeeded: first >> 32),
            UInt8(truncatingIfNeeded: first >> 24), UInt8(truncatingIfNeeded: first >> 16), UInt8(truncatingIfNeeded: first >> 8), UInt8(truncatingIfNeeded: first),
            UInt8(truncatingIfNeeded: second >> 56), UInt8(truncatingIfNeeded: second >> 48), UInt8(truncatingIfNeeded: second >> 40), UInt8(truncatingIfNeeded: second >> 32),
            UInt8(truncatingIfNeeded: second >> 24), UInt8(truncatingIfNeeded: second >> 16), UInt8(truncatingIfNeeded: second >> 8), UInt8(truncatingIfNeeded: second)
        ))
    }
}
