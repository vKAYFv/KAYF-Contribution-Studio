import SwiftUI

struct OverviewView: View {
    @Bindable var state: AppState

    var body: some View {
        if let project = state.project {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(project)
                    HStack(spacing: 10) {
                        KStatusBadge(title: "Git Ready", isReady: state.gitAvailable && state.repository != nil)
                        KStatusBadge(title: "Identity Ready", isReady: project.identity.isValid)
                        KStatusBadge(title: "Remote Connected", isReady: state.repository?.remotes.contains(where: { $0.name == "origin" }) == true)
                    }
                    KCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Text(project.configuration.preset.rawValue).font(.headline)
                                Spacer()
                                Text("Draft Pattern").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            }
                            KHeatmap(days: project.contributions, theme: state.settings.theme, maximumCount: project.configuration.maximumCommits, customPalette: state.settings.customPalette, selectedDate: $state.selectedDay)
                                .frame(minHeight: 150)
                            Divider()
                            HStack(spacing: 24) {
                                KMetric(title: "Total Contributions", value: state.totalCommits.formatted())
                                KMetric(title: "Active Days", value: state.activeDays.formatted())
                                KMetric(title: "Average", value: state.averagePerActiveDay.formatted(.number.precision(.fractionLength(1))) + "/day")
                                KMetric(title: "Peak Day", value: "\(state.peakCount) commits")
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        Button("Edit Pattern") { state.selection = .designer }
                        Button("Generate Commits") { state.createCommitPlan() }.buttonStyle(.borderedProminent).keyboardShortcut("g", modifiers: [.command, .shift])
                    }
                }
                .padding(28)
            }
        } else {
            KEmptyState(icon: "square.grid.3x3.square", title: "No Project", message: "Create or open a Git repository to begin.")
        }
    }

    private func header(_ project: ContributionProject) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(project.name).font(.largeTitle.weight(.semibold))
                Text(project.repositoryPath.path).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer()
            Label(state.repository?.branch ?? project.defaultBranch, systemImage: "arrow.triangle.branch").font(.system(.callout, design: .monospaced)).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
