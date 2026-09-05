import AppKit
import Foundation
import Observation

enum AppDestination: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case designer = "Contribution Designer"
    case commitPlan = "Commit Plan"
    case repository = "Git Repository"
    case identity = "Identity"
    case remote = "Remote"
    case history = "History"
    case logs = "Logs"
    case settings = "Settings"

    var id: Self { self }
    var icon: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .designer: "paintbrush.pointed"
        case .commitPlan: "list.bullet.rectangle"
        case .repository: "externaldrive"
        case .identity: "person.crop.circle"
        case .remote: "network"
        case .history: "clock.arrow.circlepath"
        case .logs: "text.alignleft"
        case .settings: "gearshape"
        }
    }
}

enum GenerationPhase: String {
    case idle, validating, generating, generated, failed
}

@MainActor
@Observable
final class AppState {
    var selection: AppDestination = .overview
    var project: ContributionProject?
    var repository: GitRepository?
    var settings = AppSettings()
    var history: [HistoryEntry] = []
    var logs: [LogEntry] = []
    var showsOnboarding = false
    var showsGeneration = false
    var showsDryRun = false
    var showsPushConfirmation = false
    var dryRunReport: DryRunReport?
    var selectedDay: Date?
    var paintTool: PaintTool = .pointer
    var brushCount = 4
    var generationPhase: GenerationPhase = .idle
    var generationProgress = 0
    var generationStartedAt: Date?
    var generationIsPaused = false
    var errorMessage: String?
    var gitAvailable = false
    var remoteTestSucceeded: Bool?

    @ObservationIgnored private let gitService: GitService
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private var generationControl: GenerationControl?
    @ObservationIgnored private var generationTask: Task<Void, Never>?

    init(gitService: GitService = GitService(), store: ProjectStore = ProjectStore()) {
        self.gitService = gitService
        self.store = store
        Task { await bootstrap() }
    }

    var totalCommits: Int { project?.contributions.reduce(0) { $0 + $1.count } ?? 0 }
    var activeDays: Int { project?.contributions.filter { $0.count > 0 }.count ?? 0 }
    var averagePerActiveDay: Double { activeDays == 0 ? 0 : Double(totalCommits) / Double(activeDays) }
    var peakCount: Int { project?.contributions.map(\.count).max() ?? 0 }
    var isGenerating: Bool { generationPhase == .generating }
    var progressFraction: Double {
        guard let count = project?.commitPlan?.totalCommits, count > 0 else { return 0 }
        return min(1, Double(generationProgress) / Double(count))
    }

    func bootstrap() async {
        gitAvailable = await gitService.detectGit()
        do {
            settings = try await store.loadSettings()
            history = try await store.loadHistory()
            project = try await store.loadProject()
            if let project { try await refreshRepository(at: project.repositoryPath) }
            showsOnboarding = project == nil
        } catch {
            record(error)
            showsOnboarding = true
        }
    }

    func suggestedIdentity() async -> GitIdentity {
        let global = await gitService.globalIdentity()
        return GitIdentity(
            name: settings.defaultName.isEmpty ? global.name : settings.defaultName,
            email: settings.defaultEmail.isEmpty ? global.email : settings.defaultEmail
        )
    }

    func updateConfiguration(_ mutate: (inout ContributionConfiguration) -> Void, regenerate: Bool = true, undoManager: UndoManager? = nil) {
        guard var value = project else { return }
        mutate(&value.configuration)
        project = value
        if regenerate { self.regenerate(registering: undoManager) } else { saveProject() }
    }

    func createProject(name: String, repositoryURL: URL, createRepository: Bool, branch: String, identity: GitIdentity) async -> Bool {
        do {
            if createRepository { try await gitService.initializeRepository(at: repositoryURL, branch: branch) }
            let inspected = try await gitService.inspectRepository(at: repositoryURL)
            try await gitService.configureIdentity(identity, at: repositoryURL)
            var configuration = ContributionConfiguration.defaults()
            configuration.pattern = settings.defaultPattern
            configuration.timeZoneIdentifier = settings.timezoneIdentifier
            let days = try ContributionGenerator().generate(configuration: configuration)
            let value = ContributionProject(
                name: name.isEmpty ? repositoryURL.lastPathComponent : name,
                repositoryPath: repositoryURL,
                defaultBranch: branch,
                identity: identity,
                configuration: configuration,
                contributions: days
            )
            project = value
            repository = inspected
            try await store.saveProject(value)
            showsOnboarding = false
            log("Project created at \(repositoryURL.path)")
            return true
        } catch {
            record(error)
            return false
        }
    }

    func openRepository(_ url: URL) async -> Bool {
        do {
            let inspected = try await gitService.inspectRepository(at: url)
            let global = await gitService.globalIdentity()
            let identity = await gitService.configuredIdentity(at: url, fallback: global)
            let configuration = ContributionConfiguration.defaults()
            let days = try ContributionGenerator().generate(configuration: configuration)
            let value = ContributionProject(
                name: url.lastPathComponent,
                repositoryPath: url,
                defaultBranch: inspected.branch,
                identity: identity,
                configuration: configuration,
                contributions: days
            )
            repository = inspected
            project = value
            try await store.saveProject(value)
            showsOnboarding = false
            log("Opened repository \(url.path)")
            return true
        } catch {
            record(error)
            return false
        }
    }

    func regenerate(registering undoManager: UndoManager? = nil) {
        guard var value = project else { return }
        do {
            let previous = value.contributions
            value.contributions = try ContributionGenerator().generate(configuration: value.configuration)
            value.commitPlan = nil
            value.updatedAt = .now
            project = value
            registerUndo(previous: previous, undoManager: undoManager)
            saveProject()
            log("Regenerated \(value.configuration.pattern.title) pattern with seed \(value.configuration.seed)")
        } catch { record(error) }
    }

    func applyDatePreset(_ preset: DateRangePreset, undoManager: UndoManager? = nil) {
        guard var value = project else { return }
        value.configuration.preset = preset
        if preset != .custom {
            let range = DateUtilities.applyingPreset(preset)
            value.configuration.startDate = range.lowerBound
            value.configuration.endDate = range.upperBound
        }
        project = value
        regenerate(registering: undoManager)
    }

    func randomizeSeed(undoManager: UndoManager? = nil) {
        guard var value = project else { return }
        value.configuration.seed = UInt64.random(in: UInt64.min...UInt64.max)
        project = value
        regenerate(registering: undoManager)
    }

    func setContribution(on date: Date, count: Int, undoManager: UndoManager? = nil) {
        guard var value = project, let index = value.contributions.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else { return }
        let previous = value.contributions
        value.contributions[index].count = max(0, count)
        value.contributions[index].isManual = true
        value.commitPlan = nil
        value.updatedAt = .now
        project = value
        registerUndo(previous: previous, undoManager: undoManager)
        saveProject()
    }

    func clearAll(undoManager: UndoManager? = nil) { transformDays(undoManager: undoManager) { _ in 0 } }
    func fillEmpty(with count: Int, undoManager: UndoManager? = nil) {
        transformDays(undoManager: undoManager) { $0 == 0 ? max(1, count) : $0 }
    }
    func invert(undoManager: UndoManager? = nil) {
        let maximum = project?.configuration.maximumCommits ?? 0
        transformDays(undoManager: undoManager) { maximum - min(maximum, $0) }
    }
    func randomizeDays(undoManager: UndoManager? = nil) { randomizeSeed(undoManager: undoManager) }
    func normalize(undoManager: UndoManager? = nil) {
        let maximum = project?.configuration.maximumCommits ?? 1
        transformDays(undoManager: undoManager) { $0 == 0 ? 0 : max(1, min(maximum, Int((Double($0) / Double(maximum) * 8).rounded()))) }
    }
    func smooth(undoManager: UndoManager? = nil) {
        guard var value = project else { return }
        let previous = value.contributions
        let counts = previous.indices.map { index -> Int in
            let range = max(0, index - 1)...min(previous.count - 1, index + 1)
            return Int((Double(range.reduce(0) { $0 + previous[$1].count }) / Double(range.count)).rounded())
        }
        for index in value.contributions.indices { value.contributions[index].count = counts[index]; value.contributions[index].isManual = true }
        value.commitPlan = nil
        project = value
        registerUndo(previous: previous, undoManager: undoManager)
        saveProject()
    }

    func applyTextArt(_ text: String, intensity: Int, offset: Int, background: Int, undoManager: UndoManager? = nil) {
        guard var value = project else { return }
        let previous = value.contributions
        value.contributions = TextArtGenerator().apply(text: text, to: value.contributions, intensity: intensity, horizontalOffset: offset, background: background)
        value.commitPlan = nil
        value.updatedAt = .now
        project = value
        registerUndo(previous: previous, undoManager: undoManager)
        saveProject()
    }

    func createCommitPlan() {
        guard var value = project else { return }
        do {
            let custom = settings.customMessages.split(separator: "\n").map(String.init)
            value.commitPlan = try CommitPlanner().makePlan(
                days: value.contributions,
                configuration: value.configuration,
                strategy: settings.messageStrategy,
                customMessages: custom
            )
            value.updatedAt = .now
            project = value
            selection = .commitPlan
            saveProject()
            log("Created commit plan with \(value.commitPlan?.totalCommits ?? 0) commits")
        } catch { record(error) }
    }

    func performDryRun() async {
        guard let project, let plan = project.commitPlan else { return }
        generationPhase = .validating
        do {
            dryRunReport = try await gitService.dryRun(repository: project.repositoryPath, plan: plan, identity: project.identity)
            showsDryRun = true
            generationPhase = .idle
            log("Repository validation completed")
        } catch { generationPhase = .failed; record(error) }
    }

    func startGeneration() {
        guard let project, let plan = project.commitPlan, !isGenerating else { return }
        let control = GenerationControl()
        generationControl = control
        generationPhase = .generating
        generationIsPaused = false
        generationProgress = 0
        generationStartedAt = .now
        showsDryRun = false
        showsGeneration = true
        log("Generating commit 1 / \(plan.totalCommits)")

        generationTask = Task {
            do {
                let result = try await gitService.generate(
                    repository: project.repositoryPath,
                    projectName: project.name,
                    plan: plan,
                    identity: project.identity,
                    timeZoneIdentifier: project.configuration.timeZoneIdentifier,
                    control: control
                ) { [weak self] count, commit in
                    await MainActor.run {
                        self?.generationProgress = count
                        if count == 1 || count.isMultiple(of: 100) { self?.log("Generating commit \(count) / \(plan.totalCommits) — \(commit.date.formatted(date: .abbreviated, time: .omitted))") }
                    }
                }
                guard var updated = self.project else { return }
                updated.generationSession = result.session
                if var generatedPlan = updated.commitPlan {
                    for index in generatedPlan.commits.indices { generatedPlan.commits[index].status = .generated }
                    updated.commitPlan = generatedPlan
                }
                updated.updatedAt = .now
                self.project = updated
                self.generationPhase = .generated
                self.repository = try? await self.gitService.inspectRepository(at: updated.repositoryPath)
                let entry = HistoryEntry(date: .now, pattern: updated.configuration.pattern.title, commitCount: plan.totalCommits, repositoryPath: updated.repositoryPath.path, session: result.session, completed: true)
                self.history.insert(entry, at: 0)
                try await self.store.saveHistory(self.history)
                try await self.store.saveProject(updated)
                self.log("Generation completed at \(result.finalHEAD.prefix(8))")
            } catch {
                self.generationPhase = .failed
                self.record(error)
            }
        }
    }

    func togglePause() { guard let generationControl else { return }; generationIsPaused.toggle(); Task { await generationControl.togglePause() } }
    func cancelGeneration() { guard let generationControl else { return }; Task { await generationControl.cancel() } }

    func undoGeneratedHistory() async {
        guard let project, let session = project.generationSession else { return }
        do {
            try await gitService.undo(session: session, repository: project.repositoryPath)
            var updated = project
            updated.generationSession = nil
            self.project = updated
            try await store.saveProject(updated)
            try await refreshRepository(at: updated.repositoryPath)
            log("Restored repository to its pre-generation state")
        } catch { record(error) }
    }

    func updateIdentity(_ identity: GitIdentity) async {
        guard var value = project else { return }
        do {
            try await gitService.configureIdentity(identity, at: value.repositoryPath)
            value.identity = identity
            project = value
            try await store.saveProject(value)
            log("Repository identity updated")
        } catch { record(error) }
    }

    func updateRemote(_ remoteURL: String) async {
        guard let project else { return }
        do {
            try await gitService.setRemote(url: remoteURL, at: project.repositoryPath)
            try await refreshRepository(at: project.repositoryPath)
            log("Updated origin remote")
        } catch { record(error) }
    }

    func testRemote() async {
        guard let project else { return }
        do { try await gitService.testRemote(at: project.repositoryPath); remoteTestSucceeded = true; log("Remote connection succeeded") }
        catch { remoteTestSucceeded = false; record(error) }
    }

    func fetchRemote() async {
        guard let project else { return }
        do { try await gitService.fetch(at: project.repositoryPath); log("Fetched origin") }
        catch { record(error) }
    }

    func pushGeneratedHistory() async {
        guard let project, let session = project.generationSession else { return }
        do { try await gitService.push(branch: session.generatedBranch, at: project.repositoryPath); showsPushConfirmation = false; log("Pushed \(session.generatedBranch) to origin") }
        catch { record(error) }
    }

    func saveSettings() {
        Task { do { try await store.saveSettings(settings) } catch { await MainActor.run { record(error) } } }
    }

    func saveCurrentProject() { saveProject() }

    func clearLogs() { logs.removeAll() }

    private func refreshRepository(at url: URL) async throws { repository = try await gitService.inspectRepository(at: url) }
    private func saveProject() {
        guard let project else { return }
        Task { do { try await store.saveProject(project) } catch { await MainActor.run { record(error) } } }
    }
    private func transformDays(undoManager: UndoManager?, transform: (Int) -> Int) {
        guard var value = project else { return }
        let previous = value.contributions
        for index in value.contributions.indices { value.contributions[index].count = max(0, transform(value.contributions[index].count)); value.contributions[index].isManual = true }
        value.commitPlan = nil
        project = value
        registerUndo(previous: previous, undoManager: undoManager)
        saveProject()
    }
    private func registerUndo(previous: [ContributionDay], undoManager: UndoManager?) {
        undoManager?.registerUndo(withTarget: self) { target in target.restoreDays(previous, undoManager: undoManager) }
    }
    private func restoreDays(_ days: [ContributionDay], undoManager: UndoManager?) {
        guard var value = project else { return }
        let current = value.contributions
        value.contributions = days
        value.commitPlan = nil
        project = value
        registerUndo(previous: current, undoManager: undoManager)
        saveProject()
    }
    private func log(_ message: String, level: LogEntry.Level = .info) { logs.append(LogEntry(level: level, message: message)) }
    private func record(_ error: Error) {
        errorMessage = redact((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        log(errorMessage ?? "Unknown error", level: .error)
    }

    private func redact(_ message: String) -> String {
        message.replacingOccurrences(of: #"(https?://)[^/@\s]+:[^/@\s]+@"#, with: "$1•••@", options: .regularExpression)
    }
}
