import Foundation

enum ContributionPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case natural, balanced, heavy, light, weekdays, bursts, waves, dense, custom

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum DateRangePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case threeMonths = "Last 3 months"
    case sixMonths = "Last 6 months"
    case twelveMonths = "Last 12 months"
    case currentYear = "Current year"
    case previousYear = "Previous year"
    case custom = "Custom"

    var id: Self { self }
}

struct ContributionConfiguration: Codable, Equatable, Sendable {
    var startDate: Date
    var endDate: Date
    var preset: DateRangePreset
    var pattern: ContributionPattern
    var seed: UInt64
    var activeDayFrequency: Double
    var minimumCommits: Int
    var maximumCommits: Int
    var saturdayFactor: Double
    var sundayFactor: Double
    var workdayStartHour: Int
    var workdayEndHour: Int
    var randomizeTimes: Bool
    var timeZoneIdentifier: String

    static func defaults(now: Date = .now, calendar: Calendar = .current) -> Self {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .year, value: -1, to: end) ?? end
        return .init(
            startDate: start,
            endDate: end,
            preset: .twelveMonths,
            pattern: .natural,
            seed: 482_931,
            activeDayFrequency: 0.78,
            minimumCommits: 1,
            maximumCommits: 12,
            saturdayFactor: 0.40,
            sundayFactor: 0.25,
            workdayStartHour: 9,
            workdayEndHour: 22,
            randomizeTimes: true,
            timeZoneIdentifier: TimeZone.current.identifier
        )
    }

    var isValid: Bool {
        startDate <= endDate && maximumCommits >= minimumCommits && minimumCommits >= 0 && maximumCommits <= 10_000
    }
}

struct ContributionDay: Identifiable, Codable, Hashable, Sendable {
    var date: Date
    var count: Int
    var isManual: Bool = false
    var id: Date { date }
}

enum ContributionTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case github = "GitHub"
    case purple = "Purple"
    case blue = "Blue"
    case orange = "Orange"
    case monochrome = "Monochrome"
    case custom = "Custom"
    var id: Self { self }
}

struct ThemeColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1

    static let github: [ThemeColor] = [
        .init(red: 0.12, green: 0.14, blue: 0.16, opacity: 0.35),
        .init(red: 0.05, green: 0.43, blue: 0.20),
        .init(red: 0.10, green: 0.56, blue: 0.27),
        .init(red: 0.18, green: 0.70, blue: 0.34),
        .init(red: 0.23, green: 0.82, blue: 0.43)
    ]
}

enum PaintTool: String, CaseIterable, Identifiable, Sendable {
    case pointer = "Pointer"
    case brush = "Brush"
    case erase = "Erase"
    case fill = "Fill"
    var id: Self { self }
}

enum HeatmapIntensity {
    static func level(for count: Int, maximum: Int) -> Int {
        guard count > 0, maximum > 0 else { return 0 }
        let ratio = Double(count) / Double(maximum)
        switch ratio {
        case ..<0.25: return 1
        case ..<0.50: return 2
        case ..<0.75: return 3
        default: return 4
        }
    }
}
