import Foundation

enum DateUtilities {
    static func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar
    }

    static func days(from start: Date, through end: Date, calendar: Calendar) -> [Date] {
        guard start <= end else { return [] }
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while cursor <= last {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    static func applyingPreset(_ preset: DateRangePreset, now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let start: Date
        let end: Date
        switch preset {
        case .threeMonths: start = calendar.date(byAdding: .month, value: -3, to: today) ?? today; end = today
        case .sixMonths: start = calendar.date(byAdding: .month, value: -6, to: today) ?? today; end = today
        case .twelveMonths: start = calendar.date(byAdding: .year, value: -1, to: today) ?? today; end = today
        case .currentYear:
            start = calendar.date(from: calendar.dateComponents([.year], from: today)) ?? today; end = today
        case .previousYear:
            let year = calendar.component(.year, from: today) - 1
            start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
            end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? today
        case .custom: start = today; end = today
        }
        return start...end
    }

    static func iso8601(_ date: Date, timeZoneIdentifier: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return formatter.string(from: date)
    }
}
