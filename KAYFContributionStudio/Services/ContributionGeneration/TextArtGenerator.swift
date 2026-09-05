import Foundation

struct TextArtGenerator: Sendable {
    private let glyphs: [Character: [String]] = [
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
        "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
        "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
        "♥": ["00000", "01010", "11111", "11111", "01110", "00100", "00000"]
    ]

    func apply(text: String, to days: [ContributionDay], intensity: Int, horizontalOffset: Int = 0, background: Int = 0) -> [ContributionDay] {
        guard !days.isEmpty else { return [] }
        let characters = Array(text.uppercased()).compactMap { glyphs[$0].map { ($0, $0) } }.map(\.1)
        guard !characters.isEmpty else { return days }
        let width = characters.count * 6 - 1
        let first = days[0].date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let firstWeekday = calendar.component(.weekday, from: first) - 1

        return days.enumerated().map { index, day in
            let position = firstWeekday + index
            let week = position / 7 - horizontalOffset
            let row = position % 7
            guard week >= 0, week < width else {
                return ContributionDay(date: day.date, count: background, isManual: true)
            }
            let glyphIndex = week / 6
            let column = week % 6
            guard glyphIndex < characters.count, column < 5 else {
                return ContributionDay(date: day.date, count: background, isManual: true)
            }
            let line = characters[glyphIndex][row]
            let pixel = line[line.index(line.startIndex, offsetBy: column)] == "1"
            return ContributionDay(date: day.date, count: pixel ? max(1, intensity) : background, isManual: true)
        }
    }
}
