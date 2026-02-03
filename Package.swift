// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubStackClient",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SubStackClient",
            path: "Sources"
        ),
    ]
)
