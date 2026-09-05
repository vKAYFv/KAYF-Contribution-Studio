import Foundation

protocol ContributionGenerating: Sendable {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay]
}

struct ContributionGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        guard configuration.isValid else {
            throw ContributionError.invalidConfiguration("Minimum and maximum commit counts are invalid.")
        }
        let calendar = DateUtilities.calendar(timeZoneIdentifier: configuration.timeZoneIdentifier)
        guard let fiveYears = calendar.date(byAdding: .year, value: 5, to: configuration.startDate),
              configuration.endDate <= fiveYears else {
            throw ContributionError.invalidDateRange
        }

        let dates = DateUtilities.days(from: configuration.startDate, through: configuration.endDate, calendar: calendar)
        var random = SplitMix64(seed: configuration.seed)
        var burstDays = 0
        var recoveryDays = 0
        var continuity = 0.0

        return dates.enumerated().map { index, date in
            let weekday = calendar.component(.weekday, from: date)
            let progress = dates.count > 1 ? Double(index) / Double(dates.count - 1) : 0
            let weekly = weekdayFactor(weekday, configuration: configuration)
            let month = monthlyFactor(date, calendar: calendar, seed: configuration.seed)
            let trend = 0.88 + (0.24 * progress)

            if burstDays == 0, recoveryDays == 0, random.unit() < 0.022 {
                burstDays = random.integer(in: 2...7)
            }
            if burstDays == 0, recoveryDays == 0, random.unit() < 0.015 {
                recoveryDays = random.integer(in: 3...12)
            }

            let cluster: Double
            if burstDays > 0 { cluster = 1.45; burstDays -= 1 }
            else if recoveryDays > 0 { cluster = 0.16; recoveryDays -= 1 }
            else { cluster = 1 }

            continuity = (continuity * 0.68) + (random.gaussian() * 0.32)
            let noise = max(0.35, min(1.75, 1 + continuity * 0.26))
            let preset = presetFactors(configuration.pattern, progress: progress, index: index)
            let probability = min(0.99, max(0, configuration.activeDayFrequency * weekly * month * trend * cluster * noise * preset.activity))

            guard random.unit() < probability, configuration.maximumCommits > 0 else {
                return ContributionDay(date: date, count: 0)
            }

            let span = max(0, configuration.maximumCommits - configuration.minimumCommits)
            let weighted = pow(random.unit(), preset.countCurve)
            var count = configuration.minimumCommits + Int((Double(span) * weighted).rounded())
            if cluster > 1 { count += random.integer(in: 0...max(1, span / 3)) }
            count = min(configuration.maximumCommits, max(configuration.minimumCommits, count))
            return ContributionDay(date: date, count: count)
        }
    }

    private func weekdayFactor(_ weekday: Int, configuration: ContributionConfiguration) -> Double {
        switch weekday {
        case 1: configuration.sundayFactor
        case 7: configuration.saturdayFactor
        default: 1
        }
    }

    private func monthlyFactor(_ date: Date, calendar: Calendar, seed: UInt64) -> Double {
        let month = calendar.component(.month, from: date)
        var random = SplitMix64(seed: seed &+ UInt64(month) &* 0x9E3779B97F4A7C15)
        return 0.82 + random.unit() * 0.36
    }

    private func presetFactors(_ pattern: ContributionPattern, progress: Double, index: Int) -> (activity: Double, countCurve: Double) {
        switch pattern {
        case .natural: (1, 1.65)
        case .balanced: (1.05, 1)
        case .heavy: (1.22, 0.62)
        case .light: (0.62, 2.2)
        case .weekdays: (1.05, 1.5)
        case .bursts: (index % 28 < 9 ? 1.35 : 0.28, 0.75)
        case .waves: (0.62 + (sin(progress * .pi * 8) + 1) * 0.45, 1.15)
        case .dense: (1.35, 0.45)
        case .custom: (1, 1)
        }
    }
}

struct NaturalGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        var value = configuration; value.pattern = .natural
        return try ContributionGenerator().generate(configuration: value)
    }
}
struct BalancedGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        var value = configuration; value.pattern = .balanced
        return try ContributionGenerator().generate(configuration: value)
    }
}
struct HeavyGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        var value = configuration; value.pattern = .heavy
        return try ContributionGenerator().generate(configuration: value)
    }
}
struct LightGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        var value = configuration; value.pattern = .light
        return try ContributionGenerator().generate(configuration: value)
    }
}
struct WeekdayGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        var value = configuration; value.pattern = .weekdays
        return try ContributionGenerator().generate(configuration: value)
    }
}
struct BurstGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        var value = configuration; value.pattern = .bursts
        return try ContributionGenerator().generate(configuration: value)
    }
}
struct WaveGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        var value = configuration; value.pattern = .waves
        return try ContributionGenerator().generate(configuration: value)
    }
}
struct DenseGenerator: ContributionGenerating {
    func generate(configuration: ContributionConfiguration) throws -> [ContributionDay] {
        var value = configuration; value.pattern = .dense
        return try ContributionGenerator().generate(configuration: value)
    }
}
