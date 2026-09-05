import SwiftUI

struct KHeatmap: View {
    let days: [ContributionDay]
    let theme: ContributionTheme
    let maximumCount: Int
    var customPalette: [ThemeColor] = ThemeColor.github
    @Binding var selectedDate: Date?
    var paintTool: PaintTool = .pointer
    var brushCount = 4
    var onUpdate: ((Date, Int) -> Void)?
    var onFill: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredDate: Date?
    @State private var lastPaintedDate: Date?

    private let cell: CGFloat = 13
    private let gap: CGFloat = 3
    private let labelWidth: CGFloat = 30
    private let monthHeight: CGFloat = 18

    var body: some View {
        let layout = HeatmapLayout(days: days)
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 8) {
                weekdayLabels
                    .padding(.top, monthHeight)
                    .frame(width: labelWidth)
                VStack(alignment: .leading, spacing: 4) {
                    monthLabels(layout)
                    grid(layout)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: days)
        .focusable()
        .onKeyPress { press in handleKeyPress(press, layout: layout) }
        .onDeleteCommand { updateSelected(count: 0) }
    }

    private var weekdayLabels: some View {
        VStack(spacing: gap) {
            ForEach(0..<7, id: \.self) { row in
                Text(row == 1 ? "Mon" : row == 3 ? "Wed" : row == 5 ? "Fri" : "")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: labelWidth, height: cell, alignment: .trailing)
            }
        }
    }

    private func monthLabels(_ layout: HeatmapLayout) -> some View {
        ZStack(alignment: .leading) {
            Color.clear.frame(width: layout.width(cell: cell, gap: gap), height: monthHeight)
            ForEach(layout.monthLabels, id: \.date) { label in
                Text(label.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .offset(x: CGFloat(label.week) * (cell + gap))
            }
        }
    }

    private func grid(_ layout: HeatmapLayout) -> some View {
        HStack(spacing: gap) {
            ForEach(layout.weeks.indices, id: \.self) { week in
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { row in
                        if let day = layout.weeks[week][row] {
                            heatmapCell(day)
                        } else {
                            Color.clear.frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { value in
                guard paintTool != .pointer, let day = layout.day(at: value.location, cell: cell, gap: gap) else { return }
                guard lastPaintedDate != day.date else { return }
                lastPaintedDate = day.date
                interact(with: day)
            }.onEnded { _ in lastPaintedDate = nil }
        )
    }

    private func heatmapCell(_ day: ContributionDay) -> some View {
        let level = HeatmapIntensity.level(for: day.count, maximum: maximumCount)
        let isSelected = selectedDate.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false
        let isHovered = hoveredDate.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(theme.color(level: level, colorScheme: colorScheme, customPalette: customPalette))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(isSelected ? Color.primary : .clear, lineWidth: 1.5))
            .frame(width: cell, height: cell)
            .scaleEffect(isHovered ? 1.14 : 1)
            .contentShape(Rectangle())
            .onHover { inside in hoveredDate = inside ? day.date : nil }
            .onTapGesture { interact(with: day) }
            .contextMenu {
                Menu("Set Contributions") {
                    ForEach(0...9, id: \.self) { count in Button("\(count)") { onUpdate?(day.date, count) } }
                }
                Button("Clear Day") { onUpdate?(day.date, 0) }
                Button("Randomize Day") { onUpdate?(day.date, Int.random(in: 1...max(1, maximumCount))) }
            }
            .help("\(day.date.formatted(date: .complete, time: .omitted))\n\(day.count) contribution\(day.count == 1 ? "" : "s")")
            .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
            .accessibilityValue("\(day.count) contributions")
    }

    private func interact(with day: ContributionDay) {
        selectedDate = day.date
        switch paintTool {
        case .pointer: break
        case .brush: onUpdate?(day.date, brushCount)
        case .erase: onUpdate?(day.date, 0)
        case .fill: onFill?()
        }
    }

    private func updateSelected(count: Int) {
        guard let selectedDate else { return }
        onUpdate?(selectedDate, count)
    }

    private func handleKeyPress(_ press: KeyPress, layout: HeatmapLayout) -> KeyPress.Result {
        if let count = Int(press.characters), (0...9).contains(count) {
            updateSelected(count: count)
            return .handled
        }
        guard let selectedDate, let index = layout.days.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) else { return .ignored }
        let delta: Int
        switch press.key {
        case .leftArrow: delta = -7
        case .rightArrow: delta = 7
        case .upArrow: delta = -1
        case .downArrow: delta = 1
        default: return .ignored
        }
        let target = min(max(0, index + delta), layout.days.count - 1)
        self.selectedDate = layout.days[target].date
        return .handled
    }
}

private struct HeatmapLayout {
    let days: [ContributionDay]
    let weeks: [[ContributionDay?]]
    let monthLabels: [(date: Date, week: Int)]

    init(days: [ContributionDay]) {
        self.days = days.sorted { $0.date < $1.date }
        guard let first = self.days.first else { weeks = []; monthLabels = []; return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let leading = calendar.component(.weekday, from: first.date) - 1
        var slots = Array<ContributionDay?>(repeating: nil, count: leading) + self.days.map(Optional.some)
        let trailing = (7 - (slots.count % 7)) % 7
        slots += Array(repeating: nil, count: trailing)
        weeks = stride(from: 0, to: slots.count, by: 7).map { Array(slots[$0..<min($0 + 7, slots.count)]) }
        var seen = Set<String>()
        monthLabels = weeks.enumerated().compactMap { week, values in
            guard let date = values.compactMap({ $0?.date }).first else { return nil }
            let key = "\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))"
            guard seen.insert(key).inserted else { return nil }
            return (date, week)
        }
    }

    func width(cell: CGFloat, gap: CGFloat) -> CGFloat { CGFloat(weeks.count) * cell + CGFloat(max(0, weeks.count - 1)) * gap }

    func day(at point: CGPoint, cell: CGFloat, gap: CGFloat) -> ContributionDay? {
        let stride = cell + gap
        let week = Int(point.x / stride)
        let row = Int(point.y / stride)
        guard weeks.indices.contains(week), (0..<7).contains(row) else { return nil }
        return weeks[week][row]
    }
}
