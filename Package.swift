// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpenClaudeUsageTray",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "OpenClaudeUsageTray"),
        .testTarget(name: "OpenClaudeUsageTrayTests", dependencies: ["OpenClaudeUsageTray"]),
    ]
)
