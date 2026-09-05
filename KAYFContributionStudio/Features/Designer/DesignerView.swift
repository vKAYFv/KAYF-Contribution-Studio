import SwiftUI

struct DesignerView: View {
    @Bindable var state: AppState
    @Environment(\.undoManager) private var undoManager
    @State private var showsArt = false
    @State private var artText = "KAYF"
    @State private var artIntensity = 8
    @State private var artOffset = 0
    @State private var artBackground = 0

    var body: some View {
        if let project = state.project {
            VStack(spacing: 0) {
                toolbar
                Divider()
                HStack(spacing: 0) {
                    inspector(project)
                        .frame(width: 290)
                    Divider()
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            KSectionHeader(title: "Contribution Designer", subtitle: "Draft pattern — Git history has not been generated")
                            Spacer()
                            Button("Contribution Art", systemImage: "character.cursor.ibeam", action: { showsArt.toggle() })
                                .popover(isPresented: $showsArt) { contributionArt.padding(20).frame(width: 330) }
                        }
                        KCard {
                            KHeatmap(
                                days: project.contributions,
                                theme: state.settings.theme,
                                maximumCount: project.configuration.maximumCommits,
                                customPalette: state.settings.customPalette,
                                selectedDate: $state.selectedDay,
                                paintTool: state.paintTool,
                                brushCount: state.brushCount,
                                onUpdate: { state.setContribution(on: $0, count: $1, undoManager: undoManager) },
                                onFill: { state.fillEmpty(with: state.brushCount, undoManager: undoManager) }
                            )
                            .frame(minHeight: 150)
                        }
                        HStack(spacing: 20) {
                            KMetric(title: "Contributions", value: state.totalCommits.formatted())
                            KMetric(title: "Active Days", value: state.activeDays.formatted())
                            KMetric(title: "Peak", value: state.peakCount.formatted())
                            if let selected = selectedDay(in: project) {
                                KMetric(title: selected.date.formatted(date: .abbreviated, time: .omitted), value: "\(selected.count)")
                            }
                        }
                        Spacer()
                    }
                    .padding(24)
                }
            }
        } else {
            KEmptyState(icon: "paintbrush", title: "No pattern", message: "Create a project first.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            ForEach(PaintTool.allCases) { tool in
                KToolbarButton(title: tool.rawValue, systemImage: icon(for: tool), selected: state.paintTool == tool) { state.paintTool = tool }
            }
            Divider().frame(height: 22)
            Picker("Brush", selection: $state.brushCount) {
                ForEach([1, 2, 3, 4, 6, 8, 12], id: \.self) { Text("\($0)").tag($0) }
            }
            .labelsHidden().frame(width: 72).disabled(state.paintTool != .brush && state.paintTool != .fill)
            Spacer()
            Button("Clear All") { state.clearAll(undoManager: undoManager) }
            Button("Invert") { state.invert(undoManager: undoManager) }
            Button("Randomize") { state.randomizeDays(undoManager: undoManager) }
            Button("Smooth") { state.smooth(undoManager: undoManager) }
            Button("Normalize") { state.normalize(undoManager: undoManager) }
            Divider().frame(height: 22)
            Button("Create Plan") { state.createCommitPlan() }.buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func inspector(_ project: ContributionProject) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                inspectorSection("DATE RANGE") {
                    Picker("Preset", selection: presetBinding) {
                        ForEach(DateRangePreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    DatePicker("Start", selection: startDateBinding, displayedComponents: .date)
                    DatePicker("End", selection: endDateBinding, displayedComponents: .date)
                }
                inspectorSection("PATTERN") {
                    Picker("Preset", selection: patternBinding) {
                        ForEach(ContributionPattern.allCases) { Text($0.title).tag($0) }
                    }
                    LabeledContent("Seed") {
                        HStack(spacing: 5) {
                            TextField("Seed", value: seedBinding, format: .number).frame(width: 95).textFieldStyle(.roundedBorder)
                            Button { state.randomizeSeed(undoManager: undoManager) } label: { Image(systemName: "shuffle") }.help("Randomize seed")
                        }
                    }
                }
                inspectorSection("ACTIVITY") {
                    slider("Active Days", value: frequencyBinding, range: 0...1, valueLabel: "\(Int(project.configuration.activeDayFrequency * 100))%")
                    Stepper("Minimum: \(project.configuration.minimumCommits)", value: minimumBinding, in: 0...project.configuration.maximumCommits)
                    Stepper("Maximum: \(project.configuration.maximumCommits)", value: maximumBinding, in: max(1, project.configuration.minimumCommits)...100)
                    slider("Saturday", value: saturdayBinding, range: 0...1, valueLabel: "\(Int(project.configuration.saturdayFactor * 100))%")
                    slider("Sunday", value: sundayBinding, range: 0...1, valueLabel: "\(Int(project.configuration.sundayFactor * 100))%")
                    Stepper("Start hour: \(project.configuration.workdayStartHour):00", value: startHourBinding, in: 0...project.configuration.workdayEndHour)
                    Stepper("End hour: \(project.configuration.workdayEndHour):00", value: endHourBinding, in: project.configuration.workdayStartHour...23)
                    Toggle("Randomize commit times", isOn: randomizeTimeBinding)
                }
                inspectorSection("APPEARANCE") {
                    Picker("Theme", selection: themeBinding) { ForEach(ContributionTheme.allCases) { Text($0.rawValue).tag($0) } }
                }
            }
            .padding(18)
        }
        .background(.ultraThinMaterial)
    }

    private var contributionArt: some View {
        VStack(alignment: .leading, spacing: 14) {
            KSectionHeader(title: "Contribution Art", subtitle: "Built-in 5 × 7 pixel font")
            TextField("Text", text: $artText)
            Stepper("Horizontal Position: \(artOffset)", value: $artOffset, in: 0...200)
            Stepper("Intensity: \(artIntensity)", value: $artIntensity, in: 1...100)
            Stepper("Background: \(artBackground)", value: $artBackground, in: 0...20)
            HStack { Spacer(); Button("Apply") { state.applyTextArt(artText, intensity: artIntensity, offset: artOffset, background: artBackground, undoManager: undoManager); showsArt = false }.buttonStyle(.borderedProminent).disabled(artText.isEmpty) }
        }
    }

    private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, valueLabel: String) -> some View {
        VStack(spacing: 4) {
            HStack { Text(title); Spacer(); Text(valueLabel).foregroundStyle(.secondary).monospacedDigit() }
            Slider(value: value, in: range, onEditingChanged: { if !$0 { state.regenerate(registering: undoManager) } })
        }
    }

    private func icon(for tool: PaintTool) -> String {
        switch tool { case .pointer: "cursorarrow"; case .brush: "paintbrush"; case .erase: "eraser"; case .fill: "paintbrush.fill" }
    }
    private func selectedDay(in project: ContributionProject) -> ContributionDay? {
        guard let date = state.selectedDay else { return nil }
        return project.contributions.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var presetBinding: Binding<DateRangePreset> { .init(get: { state.project?.configuration.preset ?? .custom }, set: { state.applyDatePreset($0, undoManager: undoManager) }) }
    private var patternBinding: Binding<ContributionPattern> { .init(get: { state.project?.configuration.pattern ?? .natural }, set: { pattern in state.updateConfiguration({ $0.pattern = pattern }, undoManager: undoManager) }) }
    private var startDateBinding: Binding<Date> { .init(get: { state.project?.configuration.startDate ?? .now }, set: { date in state.updateConfiguration({ $0.startDate = date; $0.preset = .custom }, undoManager: undoManager) }) }
    private var endDateBinding: Binding<Date> { .init(get: { state.project?.configuration.endDate ?? .now }, set: { date in state.updateConfiguration({ $0.endDate = date; $0.preset = .custom }, undoManager: undoManager) }) }
    private var seedBinding: Binding<UInt64> { .init(get: { state.project?.configuration.seed ?? 0 }, set: { seed in state.updateConfiguration({ $0.seed = seed }, undoManager: undoManager) }) }
    private var frequencyBinding: Binding<Double> { .init(get: { state.project?.configuration.activeDayFrequency ?? 0 }, set: { value in state.updateConfiguration({ $0.activeDayFrequency = value }, regenerate: false) }) }
    private var saturdayBinding: Binding<Double> { .init(get: { state.project?.configuration.saturdayFactor ?? 0 }, set: { value in state.updateConfiguration({ $0.saturdayFactor = value }, regenerate: false) }) }
    private var sundayBinding: Binding<Double> { .init(get: { state.project?.configuration.sundayFactor ?? 0 }, set: { value in state.updateConfiguration({ $0.sundayFactor = value }, regenerate: false) }) }
    private var minimumBinding: Binding<Int> { .init(get: { state.project?.configuration.minimumCommits ?? 0 }, set: { value in state.updateConfiguration({ $0.minimumCommits = value }, undoManager: undoManager) }) }
    private var maximumBinding: Binding<Int> { .init(get: { state.project?.configuration.maximumCommits ?? 1 }, set: { value in state.updateConfiguration({ $0.maximumCommits = value }, undoManager: undoManager) }) }
    private var randomizeTimeBinding: Binding<Bool> { .init(get: { state.project?.configuration.randomizeTimes ?? true }, set: { value in state.updateConfiguration({ $0.randomizeTimes = value }, regenerate: false) }) }
    private var startHourBinding: Binding<Int> { .init(get: { state.project?.configuration.workdayStartHour ?? 9 }, set: { value in state.updateConfiguration({ $0.workdayStartHour = value }, regenerate: false) }) }
    private var endHourBinding: Binding<Int> { .init(get: { state.project?.configuration.workdayEndHour ?? 22 }, set: { value in state.updateConfiguration({ $0.workdayEndHour = value }, regenerate: false) }) }
    private var themeBinding: Binding<ContributionTheme> { .init(get: { state.settings.theme }, set: { state.settings.theme = $0; state.saveSettings() }) }
}
