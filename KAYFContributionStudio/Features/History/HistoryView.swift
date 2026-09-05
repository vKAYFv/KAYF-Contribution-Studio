import SwiftUI

struct HistoryView: View {
    @Bindable var state: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KSectionHeader(title: "History", subtitle: "Local generation sessions").padding(24)
            Divider()
            if state.history.isEmpty {
                KEmptyState(icon: "clock.arrow.circlepath", title: "No Generation History", message: "Completed generations will appear here.")
            } else {
                List(state.history) { entry in
                    HStack(spacing: 14) {
                        Image(systemName: entry.completed ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(entry.completed ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.pattern).font(.headline)
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                            Text(entry.repositoryPath).font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text("\(entry.commitCount.formatted()) commits").monospacedDigit()
                        Button("View Plan") { state.selection = .commitPlan }
                        Button("Repository") { state.selection = .repository }
                        if entry.session?.id == state.project?.generationSession?.id {
                            Button("Undo", role: .destructive) { Task { await state.undoGeneratedHistory() } }
                        }
                    }.padding(.vertical, 7)
                }
            }
        }
    }
}
