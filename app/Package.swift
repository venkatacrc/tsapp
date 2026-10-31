// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sopanam",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Sopanam",
            resources: [.copy("Resources/course.json")]
        )
    ]
)
