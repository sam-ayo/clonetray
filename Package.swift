// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CloneTray",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CloneTray",
            path: "Sources/CloneTray"
        )
    ]
)
