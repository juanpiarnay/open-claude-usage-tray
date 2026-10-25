import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var limits: [Limit] = []
    @Published private(set) var error: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false

    /// End of the current 429 backoff. Persisted so quitting and reopening can't hit the API
    /// early, since retrying before Retry-After extends the rate limit.
    @Published private(set) var blockedUntil = UserDefaults.standard.object(forKey: "blockedUntil") as? Date ?? .distantPast {
        didSet { UserDefaults.standard.set(blockedUntil, forKey: "blockedUntil") }
    }

    private var pollTask: Task<Void, Never>?

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
                blockedUntil = Date().addingTimeInterval(seconds) // popover shows a live countdown
                self.error = nil
            } else {
                self.error = error.localizedDescription
            }
        }
    }
}
