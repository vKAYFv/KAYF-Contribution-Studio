import AppKit
import SwiftUI

struct RepositoryView: View {
    @Bindable var state: AppState
    @State private var showsUndoConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                KSectionHeader(title: "Git Repository", subtitle: "Local repository state and generation safety")
                if let project = state.project, let repository = state.repository {
                    KCard {
                        VStack(alignment: .leading, spacing: 14) {
                            detail("Location", project.repositoryPath.path)
                            detail("Branch", repository.branch)
                            detail("HEAD", repository.head.map { String($0.prefix(12)) } ?? "Empty repository")
                            detail("Working Tree", repository.isDirty ? "Uncommitted changes" : "Clean")
                        }
                    }
                    KCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Safety").font(.headline)
                            Label("Existing history is generated on a dedicated kayf/contributions-* branch.", systemImage: "shield.checkered")
                            Label("Both author and committer dates are set per commit; the system clock is untouched.", systemImage: "calendar.badge.clock")
                            Label("Force push is never performed.", systemImage: "arrow.up.circle")
                        }.foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.repositoryPath]) }
                        Spacer()
                        if project.generationSession != nil {
                            Button("Undo Generated History", role: .destructive) { showsUndoConfirmation = true }
                        }
                    }
                } else {
                    KEmptyState(icon: "externaldrive.badge.questionmark", title: "Repository unavailable", message: "Open a Git repository to inspect it.")
                }
            }
            .padding(28)
        }
        .confirmationDialog("Restore pre-generation repository state?", isPresented: $showsUndoConfirmation) {
            Button("Undo Generated History", role: .destructive) { Task { await state.undoGeneratedHistory() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The generated branch and its commits will be removed locally. This cannot undo a branch that was already pushed.") }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        LabeledContent(title) { Text(value).font(.system(.body, design: title == "Location" || title == "HEAD" ? .monospaced : .default)).textSelection(.enabled) }
    }
}

struct IdentityView: View {
    @Bindable var state: AppState
    @State private var identity = GitIdentity(name: "", email: "")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                KSectionHeader(title: "Git Identity", subtitle: "Repository-local author and committer identity")
                KCard {
                    Form {
                        TextField("Name", text: $identity.name)
                        TextField("Email", text: $identity.email)
                    }
                }
                Label(identity.isValid ? "Identity ready" : "A valid name and email are required", systemImage: identity.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(identity.isValid ? Color.green : Color.orange)
                Text("GitHub generally attributes a commit only when its email is associated with your account and the commit is reachable from an eligible branch. GitHub makes the final eligibility decision.")
                    .foregroundStyle(.secondary)
                HStack { Spacer(); Button("Save Identity") { Task { await state.updateIdentity(identity) } }.buttonStyle(.borderedProminent).disabled(!identity.isValid) }
            }.padding(28)
        }
        .onAppear { identity = state.project?.identity ?? identity }
    }
}

struct RemoteView: View {
    @Bindable var state: AppState
    @State private var remoteURL = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                KSectionHeader(title: "Remote", subtitle: "Configure SSH or HTTPS and push only when you choose")
                KCard {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Origin URL", text: $remoteURL, prompt: Text("git@github.com:user/activity.git"))
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            if let result = state.remoteTestSucceeded {
                                Label(result ? "Connected" : "Unavailable", systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(result ? Color.green : Color.red)
                            }
                            Spacer()
                            Button("Save") { Task { await state.updateRemote(remoteURL) } }.disabled(remoteURL.isEmpty)
                            Button("Test Remote") { Task { await state.testRemote() } }.disabled(remoteURL.isEmpty)
                            Button("Fetch") { Task { await state.fetchRemote() } }.disabled(remoteURL.isEmpty)
                        }
                    }
                }
                if let session = state.project?.generationSession {
                    KCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Generated History").font(.headline)
                            LabeledContent("Branch", value: session.generatedBranch)
                            LabeledContent("Commits", value: session.generatedCommitCount.formatted())
                            HStack { Spacer(); Button("Push…") { state.showsPushConfirmation = true }.buttonStyle(.borderedProminent).disabled(remoteURL.isEmpty) }
                        }
                    }
                }
                KCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Contribution Eligibility").font(.headline)
                        eligibility("Commit email configured", state.project?.identity.isValid == true)
                        eligibility("Fork status requires GitHub verification", false)
                        eligibility("Default branch: \(state.project?.defaultBranch ?? "main")", true)
                        eligibility("Commits contain valid author dates", state.project?.generationSession != nil)
                        Text("GitHub ultimately determines whether commits appear on a contribution graph.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(28)
        }
        .onAppear { remoteURL = state.repository?.remotes.first(where: { $0.name == "origin" })?.url ?? "" }
    }

    private func eligibility(_ title: String, _ ready: Bool) -> some View {
        Label(title, systemImage: ready ? "checkmark.circle.fill" : "circle").foregroundStyle(ready ? Color.green : Color.secondary)
    }
}
