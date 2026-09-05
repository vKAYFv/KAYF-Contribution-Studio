import AppKit
import SwiftUI

struct CommitPlanView: View {
    @Bindable var state: AppState
    @State private var search = ""
    @State private var selectedMonth = "All"

    var body: some View {
        if let plan = state.project?.commitPlan {
            VStack(spacing: 0) {
                HStack {
                    KSectionHeader(title: "Commit Plan", subtitle: "Review planned commits before Git history is modified")
                    Spacer()
                    KMetric(title: "Planned Commits", value: plan.totalCommits.formatted()).frame(width: 145)
                    KMetric(title: "Active Days", value: plan.activeDays.formatted()).frame(width: 120)
                }
                .padding(24)
                Divider()
                HStack {
                    Picker("Month", selection: $selectedMonth) {
                        Text("All months").tag("All")
                        ForEach(months(in: plan), id: \.self) { Text($0).tag($0) }
                    }.frame(width: 220)
                    Spacer()
                    Button("Export Plan", action: { export(plan) })
                    Button("Dry Run") { Task { await state.performDryRun() } }.disabled(state.generationPhase == .validating)
                    Button("Generate") { Task { await state.performDryRun() } }.buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                Table(filtered(plan)) {
                    TableColumn("Date") { commit in Text(commit.date.formatted(date: .abbreviated, time: .omitted)) }.width(min: 130, ideal: 150)
                    TableColumn("Time") { commit in Text(commit.timestamp.formatted(date: .omitted, time: .shortened)).monospacedDigit() }.width(90)
                    TableColumn("Message") { commit in Text(commit.message) }
                    TableColumn("Status") { commit in Text(commit.status.rawValue.capitalized).foregroundStyle(commit.status == .failed ? .red : .secondary) }.width(90)
                }
            }
            .searchable(text: $search, prompt: "Search messages or dates")
        } else {
            KEmptyState(icon: "list.bullet.rectangle", title: "No Commit Plan", message: "Finish the draft pattern, then create a plan.")
                .toolbar { Button("Create Plan") { state.createCommitPlan() }.disabled(state.project == nil) }
        }
    }

    private func filtered(_ plan: CommitPlan) -> [PlannedCommit] {
        plan.commits.filter { commit in
            let month = commit.date.formatted(.dateTime.year().month(.wide))
            let matchesMonth = selectedMonth == "All" || selectedMonth == month
            let query = search.lowercased()
            let matchesSearch = query.isEmpty || commit.message.lowercased().contains(query) || commit.date.formatted(date: .abbreviated, time: .omitted).lowercased().contains(query)
            return matchesMonth && matchesSearch
        }
    }

    private func months(in plan: CommitPlan) -> [String] {
        Array(Set(plan.commits.map { $0.date.formatted(.dateTime.year().month(.wide)) })).sorted()
    }

    private func export(_ plan: CommitPlan) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "KAYF-Commit-Plan.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let rows = ["sequence,date,timestamp,message,status"] + plan.commits.map {
            "\($0.sequence),\($0.date.ISO8601Format()),\($0.timestamp.ISO8601Format()),\"\($0.message.replacingOccurrences(of: "\"", with: "\"\""))\",\($0.status.rawValue)"
        }
        try? rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
