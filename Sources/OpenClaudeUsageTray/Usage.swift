import Foundation

/// One plan limit as shown on claude.ai/settings/usage.
struct Limit: Identifiable, Equatable {
    let id: String          // API "kind": "session", "weekly_all", ...
    let percent: Int
    let severity: String?
    let resetsAt: Date?

    var title: String {
        switch id {
        case "session": return "Current session"
        case "weekly_all": return "Weekly · all models"
        default: return id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// 0 ok, 1 warning, 2 critical — same signal claude.ai uses to color its bars.
    // ponytail: only "normal" has been observed; "warning"/"critical" are guesses, anything else falls back to 80/90%.
    var level: Int {
        switch severity {
        case "normal": return 0
        case "warning": return 1
        case "critical": return 2
        default: return percent >= 90 ? 2 : percent >= 80 ? 1 : 0
        }
    }
}

enum UsageError: LocalizedError {
    case noCredentials, tokenExpired, rateLimited, http(Int)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "Claude Code credentials not found. Install Claude Code and log in."
        case .tokenExpired: return "Token expired — open Claude Code to refresh it."
        case .rateLimited: return "Rate limited — retrying in 15 min."
        case .http(let code): return "Usage API returned HTTP \(code)."
        }
    }
}

// MARK: - Parsing

private struct UsageResponse: Decodable {
    struct APILimit: Decodable {
        let kind: String
        let percent: Double
        let severity: String?
        let resetsAt: String?
    }
    struct Window: Decodable {
        let utilization: Double
        let resetsAt: String?
    }
    let limits: [APILimit]?
    let fiveHour: Window?
    let sevenDay: Window?
}

func parseLimits(_ data: Data) throws -> [Limit] {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let response = try decoder.decode(UsageResponse.self, from: data)

    if let limits = response.limits, !limits.isEmpty {
        return limits.map {
            Limit(id: $0.kind, percent: Int($0.percent), severity: $0.severity, resetsAt: parseDate($0.resetsAt))
        }
    }
    // Older response shape, without the `limits` array.
    return [("session", response.fiveHour), ("weekly_all", response.sevenDay)].compactMap { kind, window in
        window.map { Limit(id: kind, percent: Int($0.utilization), severity: nil, resetsAt: parseDate($0.resetsAt)) }
    }
}

func parseDate(_ string: String?) -> Date? {
    guard let string else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: string) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: string)
}

func countdown(to date: Date, from now: Date = Date()) -> String {
    let minutes = max(0, Int(date.timeIntervalSince(now)) / 60)
    if minutes >= 24 * 60 { return "\(minutes / 1440)d \(minutes % 1440 / 60)h" }
    if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
    return "\(minutes)m"
}

// MARK: - Fetching

/// Claude Code stores its login with /usr/bin/security, so reading through the same tool
/// is already trusted by the Keychain and never prompts for a password.
func readAccessToken() throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    struct Credentials: Decodable {
        struct OAuth: Decodable { let accessToken: String }
        let claudeAiOauth: OAuth
    }
    guard process.terminationStatus == 0,
          let credentials = try? JSONDecoder().decode(Credentials.self, from: data)
    else { throw UsageError.noCredentials }
    return credentials.claudeAiOauth.accessToken
}

/// Undocumented endpoint behind claude.ai/settings/usage; may change without notice.
func fetchLimits() async throws -> [Limit] {
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
    request.setValue("Bearer \(try readAccessToken())", forHTTPHeaderField: "Authorization")
    request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

    let (data, response) = try await URLSession.shared.data(for: request)
    switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
    case 200: return try parseLimits(data)
    case 401: throw UsageError.tokenExpired
    case 429: throw UsageError.rateLimited
    case let code: throw UsageError.http(code)
    }
}
