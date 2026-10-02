import XCTest
@testable import OpenClaudeUsageTray

// Needs full Xcode (XCTest isn't in the Command Line Tools): `swift test`.
final class UsageTests: XCTestCase {
    func testParsesLimitsArray() throws {
        let json = """
        { "limits": [
            { "kind": "session", "percent": 2, "severity": "normal", "resets_at": "2026-10-02T18:39:59.669508+00:00" },
            { "kind": "weekly_all", "percent": 85, "severity": null, "resets_at": null }
        ] }
        """
        let limits = try parseLimits(Data(json.utf8))
        XCTAssertEqual(limits.map(\.id), ["session", "weekly_all"])
        XCTAssertNotNil(limits[0].resetsAt)
        XCTAssertNil(limits[1].resetsAt)
        XCTAssertEqual(limits[0].level, 0)
        XCTAssertEqual(limits[1].level, 1) // no severity → falls back to percent
    }

    func testFallsBackToWindowsWithoutLimitsArray() throws {
        let json = """
        { "five_hour": { "utilization": 34.7, "resets_at": "2026-10-02T18:00:00+00:00" },
          "seven_day": { "utilization": 95.0, "resets_at": null } }
        """
        let limits = try parseLimits(Data(json.utf8))
        XCTAssertEqual(limits.map(\.percent), [34, 95])
        XCTAssertNotNil(limits[0].resetsAt)
        XCTAssertEqual(limits[1].level, 2)
    }

    func testSeverityWinsOverPercent() {
        XCTAssertEqual(Limit(id: "x", percent: 95, severity: "normal", resetsAt: nil).level, 0)
        XCTAssertEqual(Limit(id: "x", percent: 10, severity: "critical", resetsAt: nil).level, 2)
    }

    func testCountdown() {
        let now = Date()
        XCTAssertEqual(countdown(to: now.addingTimeInterval(45 * 60), from: now), "45m")
        XCTAssertEqual(countdown(to: now.addingTimeInterval(2 * 3600 + 30 * 60), from: now), "2h 30m")
        XCTAssertEqual(countdown(to: now.addingTimeInterval(3 * 86400 + 5 * 3600), from: now), "3d 5h")
        XCTAssertEqual(countdown(to: now.addingTimeInterval(-60), from: now), "0m")
    }
}
