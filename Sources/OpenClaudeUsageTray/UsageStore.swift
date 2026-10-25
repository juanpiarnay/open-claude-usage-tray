import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var limits: [Limit] = []
    @Published private(set) var error: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false

    private var pollTask: Task<Void, Never>?
    private var blockedUntil = Date.distantPast

    /// Polls every 5 min, or after the server's Retry-After on a 429. Task.sleep uses the
    /// continuous clock, so a poll that came due while the Mac slept runs right after wake.
    func start() {
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                let wait = max(5 * 60, blockedUntil.timeIntervalSinceNow)
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    func refresh() async {
        // A manual Refresh during a rate limit would only extend it.
        guard !isLoading, Date() >= blockedUntil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            limits = try await fetchLimits()
            lastUpdated = Date()
            error = nil
        } catch {
            if case UsageError.rateLimited(let seconds) = error {
                blockedUntil = Date().addingTimeInterval(seconds)
            }
            self.error = error.localizedDescription
        }
    }
}
