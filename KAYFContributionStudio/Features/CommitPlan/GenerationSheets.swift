import SwiftUI

struct DryRunSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            KSectionHeader(title: "Dry Run Complete", subtitle: "All validation was performed without creating commits.")
            if let report = state.dryRunReport {
                KCard {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                        row("Repository", report.repositoryPath)
                        row("Branch", report.branch)
                        row("Date Range", "\(report.dateRange.lowerBound.formatted(date: .abbreviated, time: .omitted)) → \(report.dateRange.upperBound.formatted(date: .abbreviated, time: .omitted))")
                        row("Active Days", report.activeDays.formatted())
                        row("Planned Commits", report.plannedCommits.formatted())
                        row("Estimated Time", "~\(report.estimatedSeconds) sec")
                        row("Git Identity", "\(report.identity.name) <\(report.identity.email)>")
                        row("Remote", report.remote?.url ?? "Not configured")
                    }
                }
                if report.warnings.isEmpty {
                    Label("No warnings", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    ForEach(report.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                }
                HStack {
                    Button("Cancel") { dismiss() }
                    Spacer()
                    Button("Generate \(report.plannedCommits.formatted()) Commits") { state.startGeneration() }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24).frame(width: 650)
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow { Text(title).foregroundStyle(.secondary); Text(value).font(.system(.body, design: title == "Repository" || title == "Remote" ? .monospaced : .default)).textSelection(.enabled) }
    }
}

struct GenerationProgressSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            KSectionHeader(title: title, subtitle: subtitle)
            ProgressView(value: state.progressFraction).progressViewStyle(.linear).tint(state.generationPhase == .failed ? .red : .accentColor)
            HStack {
                Text("\(state.generationProgress.formatted()) / \((state.project?.commitPlan?.totalCommits ?? 0).formatted())").monospacedDigit()
                Spacer()
                if let date = currentDate { Text(date.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary) }
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack {
                    LabeledContent("Elapsed", value: elapsed(at: context.date))
                    Spacer()
                    LabeledContent("Estimated", value: estimated(at: context.date))
                }.monospacedDigit().foregroundStyle(.secondary)
            }
            HStack {
                if state.isGenerating {
                    Button(state.generationIsPaused ? "Resume" : "Pause") { state.togglePause() }
                    Button("Cancel", role: .destructive) { state.cancelGeneration() }
                }
                Spacer()
                if !state.isGenerating { Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
            }
        }.padding(26).frame(width: 540)
    }

    private var title: String { switch state.generationPhase { case .generated: "Generation Complete"; case .failed: "Generation Stopped"; default: state.generationIsPaused ? "Generation Paused" : "Generating Contributions" } }
    private var subtitle: String { switch state.generationPhase { case .generated: "The Git history has been validated and written locally."; case .failed: state.errorMessage ?? "Generation did not complete."; default: "You can pause or cancel safely at any commit boundary." } }
    private var currentDate: Date? { guard let commits = state.project?.commitPlan?.commits, state.generationProgress > 0, state.generationProgress <= commits.count else { return nil }; return commits[state.generationProgress - 1].date }
    private func elapsed(at date: Date) -> String { guard let start = state.generationStartedAt else { return "00:00" }; return duration(max(0, Int(date.timeIntervalSince(start)))) }
    private func estimated(at date: Date) -> String { guard state.generationProgress > 0, let start = state.generationStartedAt, let total = state.project?.commitPlan?.totalCommits else { return "—" }; let elapsed = date.timeIntervalSince(start); return duration(max(0, Int((elapsed / Double(state.generationProgress)) * Double(total - state.generationProgress)))) }
    private func duration(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}

struct PushConfirmationSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            KSectionHeader(title: "Push Generated History?", subtitle: "This publishes the generated branch to your configured remote.")
            if let project = state.project, let session = project.generationSession {
                KCard {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Remote", value: state.repository?.remotes.first(where: { $0.name == "origin" })?.url ?? "origin")
                        LabeledContent("Branch", value: session.generatedBranch)
                        LabeledContent("Commits", value: session.generatedCommitCount.formatted())
                    }
                }
                Text("No force push will be used.").font(.callout).foregroundStyle(.secondary)
                HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Push") { Task { await state.pushGeneratedHistory(); dismiss() } }.buttonStyle(.borderedProminent) }
            }
        }.padding(24).frame(width: 520)
    }
}
