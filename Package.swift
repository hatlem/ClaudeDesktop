// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeDesktop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClaudeDesktop", targets: ["ClaudeDesktop"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeDesktop",
            path: "ClaudeDesktop"
        )
    ]
)
