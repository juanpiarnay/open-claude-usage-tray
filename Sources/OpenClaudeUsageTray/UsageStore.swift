import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var limits: [Limit] = []
    @Published private(set) var error: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false

    private var pollTask: Task<Void, Never>?

    /// Polls every 5 min (15 min after a 429). Task.sleep uses the continuous clock,
    /// so a poll that came due while the Mac slept runs right after wake.
    func start() {
        pollTask = Task {
            while !Task.isCancelled {
                let rateLimited = await refresh()
                try? await Task.sleep(for: .seconds(rateLimited ? 15 * 60 : 5 * 60))
            }
        }
    }

    /// Returns true when the API rate-limited us.
    @discardableResult
    func refresh() async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
            limits = try await fetchLimits()
            lastUpdated = Date()
            error = nil
            return false
        } catch UsageError.rateLimited {
            error = UsageError.rateLimited.localizedDescription
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
