import Foundation

actor GenerationControl {
    private(set) var isPaused = false
    private(set) var isCancelled = false

    func togglePause() { isPaused.toggle() }
    func cancel() { isCancelled = true; isPaused = false }

    func checkpoint() async throws {
        if isCancelled { throw GitError.cancelled }
        while isPaused {
            try await Task.sleep(for: .milliseconds(120))
            if isCancelled { throw GitError.cancelled }
            try Task.checkCancellation()
        }
        try Task.checkCancellation()
    }
}
