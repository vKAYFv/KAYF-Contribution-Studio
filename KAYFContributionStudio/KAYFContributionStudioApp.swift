import AppKit
import SwiftUI

@main
struct KAYFContributionStudioApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
        }
        .defaultSize(width: 1350, height: 850)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") { state.showsOnboarding = true }.keyboardShortcut("n", modifiers: .command)
                Button("Open Repository…", action: openRepository).keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("Save Project") { state.saveCurrentProject() }.keyboardShortcut("s", modifiers: .command).disabled(state.project == nil)
            }
            CommandMenu("Contribution") {
                Button("Regenerate Pattern") { state.regenerate() }.keyboardShortcut("r", modifiers: .command).disabled(state.project == nil)
                Button("Generate…") {
                    if state.project?.commitPlan == nil { state.createCommitPlan() }
                    else { Task { await state.performDryRun() } }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(state.project == nil)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { state.selection = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func openRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { _ = await state.openRepository(url) }
    }
}
