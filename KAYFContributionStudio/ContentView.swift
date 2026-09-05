import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var state: AppState

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            destination
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1100, minHeight: 720)
        .sheet(isPresented: $state.showsOnboarding) { OnboardingView(state: state) }
        .sheet(isPresented: $state.showsDryRun) { DryRunSheet(state: state) }
        .sheet(isPresented: $state.showsGeneration) { GenerationProgressSheet(state: state) }
        .sheet(isPresented: $state.showsPushConfirmation) { PushConfirmationSheet(state: state) }
        .alert("KAYF Contribution Studio", isPresented: errorPresented) {
            Button("OK") { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "Unknown error") }
        .preferredColorScheme(preferredScheme)
    }

    private var sidebar: some View {
        List(selection: $state.selection) {
            Section("PROJECT") {
                item(.overview)
                item(.designer)
                item(.commitPlan)
            }
            Section("REPOSITORY") {
                item(.repository)
                item(.identity)
                item(.remote)
            }
            Section("TOOLS") {
                item(.history)
                item(.logs)
            }
            Section {
                item(.settings)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Label("KAYF", systemImage: "square.grid.3x3.square.fill").font(.headline).foregroundStyle(.primary)
                Text("Contribution Studio").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 12)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 7) {
                Circle().fill(state.gitAvailable ? Color.green : Color.red).frame(width: 7, height: 7)
                Text(state.gitAvailable ? "Git ready" : "Git unavailable").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(12).background(.ultraThinMaterial)
        }
    }

    private func item(_ destination: AppDestination) -> some View {
        Label(destination.rawValue, systemImage: destination.icon).tag(destination)
    }

    @ViewBuilder private var destination: some View {
        switch state.selection {
        case .overview: OverviewView(state: state)
        case .designer: DesignerView(state: state)
        case .commitPlan: CommitPlanView(state: state)
        case .repository: RepositoryView(state: state)
        case .identity: IdentityView(state: state)
        case .remote: RemoteView(state: state)
        case .history: HistoryView(state: state)
        case .logs: LogsView(state: state)
        case .settings: SettingsView(state: state)
        }
    }

    private var errorPresented: Binding<Bool> { .init(get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } }) }
    private var preferredScheme: ColorScheme? { switch state.settings.appearance { case .system: nil; case .light: .light; case .dark: .dark } }
}
