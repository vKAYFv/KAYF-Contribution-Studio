import AppKit
import SwiftUI

struct LogsView: View {
    @Bindable var state: AppState
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                KSectionHeader(title: "Logs", subtitle: "Developer-friendly local operation log")
                Spacer()
                Button("Copy Logs", action: copyLogs)
                Button("Export Logs", action: exportLogs)
                Button("Clear", role: .destructive) { state.clearLogs() }
            }.padding(24)
            Divider()
            if state.logs.isEmpty {
                KEmptyState(icon: "text.alignleft", title: "No Log Entries", message: "Repository and generation events will appear here.")
            } else {
                List(state.logs) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(entry.timestamp.formatted(date: .omitted, time: .standard)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        Circle().fill(color(entry.level)).frame(width: 6, height: 6)
                        Text(entry.message).textSelection(.enabled)
                    }.padding(.vertical, 3)
                }
            }
        }
    }

    private var text: String { state.logs.map { "\($0.timestamp.formatted(date: .omitted, time: .standard)) [\($0.level.rawValue.uppercased())] \($0.message)" }.joined(separator: "\n") }
    private func copyLogs() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    private func exportLogs() { let panel = NSSavePanel(); panel.nameFieldStringValue = "KAYF-Logs.txt"; if panel.runModal() == .OK, let url = panel.url { try? text.write(to: url, atomically: true, encoding: .utf8) } }
    private func color(_ level: LogEntry.Level) -> Color { switch level { case .info: .blue; case .warning: .orange; case .error: .red } }
}
