import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                KSectionHeader(title: "Settings", subtitle: "Defaults for new projects and generation")
                settingsSection("General") {
                    Picker("Appearance", selection: appearanceBinding) { ForEach(AppAppearance.allCases) { Text($0.rawValue).tag($0) } }
                    Picker("Default theme", selection: themeBinding) { ForEach(ContributionTheme.allCases) { Text($0.rawValue).tag($0) } }
                    if state.settings.theme == .custom {
                        HStack {
                            ForEach(0..<5, id: \.self) { index in
                                ColorPicker(index == 0 ? "Empty" : "Level \(index)", selection: paletteBinding(index), supportsOpacity: true)
                            }
                        }
                    }
                    Picker("Default date range", selection: rangeBinding) { ForEach(DateRangePreset.allCases) { Text($0.rawValue).tag($0) } }
                }
                settingsSection("Git") {
                    LabeledContent("Git executable", value: state.gitAvailable ? "/usr/bin/env git — detected" : "Not detected")
                    TextField("Default author name", text: defaultNameBinding)
                    TextField("Default email", text: defaultEmailBinding)
                    TextField("Default branch", text: defaultBranchBinding)
                }
                settingsSection("Generation") {
                    Picker("Default pattern", selection: patternBinding) { ForEach(ContributionPattern.allCases) { Text($0.title).tag($0) } }
                    Picker("Commit messages", selection: strategyBinding) { ForEach(CommitMessageStrategy.allCases) { Text($0.rawValue).tag($0) } }
                    TextField("Timezone", text: timezoneBinding)
                    if state.settings.messageStrategy == .custom {
                        TextEditor(text: customMessagesBinding).font(.system(.body, design: .monospaced)).frame(minHeight: 100)
                    }
                }
                settingsSection("Advanced") {
                    Toggle("Show Git commands", isOn: showCommandsBinding)
                    Toggle("Enable verbose logs", isOn: verboseBinding)
                }
            }.padding(28).frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        KCard { VStack(alignment: .leading, spacing: 14) { Text(title).font(.headline); content() } }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        .init(get: { state.settings[keyPath: keyPath] }, set: { state.settings[keyPath: keyPath] = $0; state.saveSettings() })
    }
    private var appearanceBinding: Binding<AppAppearance> { binding(\.appearance) }
    private var themeBinding: Binding<ContributionTheme> { binding(\.theme) }
    private var rangeBinding: Binding<DateRangePreset> { binding(\.defaultRange) }
    private var defaultNameBinding: Binding<String> { binding(\.defaultName) }
    private var defaultEmailBinding: Binding<String> { binding(\.defaultEmail) }
    private var defaultBranchBinding: Binding<String> { binding(\.defaultBranch) }
    private var patternBinding: Binding<ContributionPattern> { binding(\.defaultPattern) }
    private var strategyBinding: Binding<CommitMessageStrategy> { binding(\.messageStrategy) }
    private var timezoneBinding: Binding<String> { binding(\.timezoneIdentifier) }
    private var customMessagesBinding: Binding<String> { binding(\.customMessages) }
    private var showCommandsBinding: Binding<Bool> { binding(\.showGitCommands) }
    private var verboseBinding: Binding<Bool> { binding(\.verboseLogs) }

    private func paletteBinding(_ index: Int) -> Binding<Color> {
        .init {
            let palette = state.settings.customPalette
            let value = palette.indices.contains(index) ? palette[index] : ThemeColor.github[index]
            return Color(red: value.red, green: value.green, blue: value.blue, opacity: value.opacity)
        } set: { color in
            let converted = NSColor(color).usingColorSpace(.deviceRGB) ?? .systemGreen
            while state.settings.customPalette.count < 5 { state.settings.customPalette.append(ThemeColor.github[state.settings.customPalette.count]) }
            state.settings.customPalette[index] = ThemeColor(red: converted.redComponent, green: converted.greenComponent, blue: converted.blueComponent, opacity: converted.alphaComponent)
            state.saveSettings()
        }
    }
}
