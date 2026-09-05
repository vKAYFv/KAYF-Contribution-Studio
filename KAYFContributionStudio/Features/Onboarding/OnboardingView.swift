import AppKit
import SwiftUI

struct OnboardingView: View {
    @Bindable var state: AppState
    @State private var page = 0
    @State private var projectName = "Activity"
    @State private var repositoryURL: URL?
    @State private var createRepository = true
    @State private var branch = "main"
    @State private var identity = GitIdentity(name: "", email: "")
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule().fill(index <= page ? Color.accentColor : Color.secondary.opacity(0.25)).frame(width: 28, height: 4)
                }
            }
            .padding(.top, 22)

            Group {
                switch page {
                case 0: welcome
                case 1: projectSetup
                default: identitySetup
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        }
        .frame(width: 660, height: 500)
        .interactiveDismissDisabled(state.project == nil)
        .task { identity = await state.suggestedIdentity() }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Image(systemName: "square.grid.3x3.square").font(.system(size: 54, weight: .light)).foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("KAYF Contribution Studio").font(.largeTitle.weight(.semibold))
                Text("Design and generate Git contribution histories locally.").font(.title3).foregroundStyle(.secondary)
            }
            VStack(spacing: 10) {
                Button("Create Project") { createRepository = true; page = 1 }.buttonStyle(.borderedProminent).controlSize(.large)
                Button("Open Existing Repository") { openExisting() }.buttonStyle(.bordered).controlSize(.large)
            }
        }
    }

    private var projectSetup: some View {
        VStack(alignment: .leading, spacing: 20) {
            KSectionHeader(title: "Create a contribution project", subtitle: "Choose where Git history will be generated.")
            Form {
                TextField("Project Name", text: $projectName)
                LabeledContent("Repository Location") {
                    HStack {
                        Text(repositoryURL?.path ?? "Not selected").lineLimit(1).foregroundStyle(repositoryURL == nil ? .secondary : .primary)
                        Button("Choose…", action: chooseDirectory)
                    }
                }
                Picker("Repository", selection: $createRepository) {
                    Text("Create new Git repository").tag(true)
                    Text("Use existing Git repository").tag(false)
                }
                TextField("Default Branch", text: $branch)
            }
            Spacer()
            HStack { Button("Back") { page = 0 }; Spacer(); Button("Continue") { page = 2 }.buttonStyle(.borderedProminent).disabled(repositoryURL == nil || projectName.isEmpty) }
        }
    }

    private var identitySetup: some View {
        VStack(alignment: .leading, spacing: 20) {
            KSectionHeader(title: "Git Identity", subtitle: "This identity is written to this repository only.")
            Form {
                TextField("Name", text: $identity.name)
                TextField("Email", text: $identity.email)
            }
            Label(identity.isValid ? "Email configured" : "Enter a valid name and email", systemImage: identity.isValid ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(identity.isValid ? Color.green : Color.orange)
            Text("For contributions to appear on a GitHub profile, the commit email generally needs to be associated with that GitHub account.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            HStack {
                Button("Back") { page = 1 }
                Spacer()
                if isWorking { ProgressView().controlSize(.small) }
                Button("Create Project") { create() }.buttonStyle(.borderedProminent).disabled(!identity.isValid || repositoryURL == nil || isWorking)
            }
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { repositoryURL = panel.url }
    }

    private func openExisting() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isWorking = true
        Task { _ = await state.openRepository(url); isWorking = false }
    }

    private func create() {
        guard let repositoryURL else { return }
        isWorking = true
        Task {
            let success = await state.createProject(name: projectName, repositoryURL: repositoryURL, createRepository: createRepository, branch: branch, identity: identity)
            if success { state.selection = .overview }
            isWorking = false
        }
    }
}
