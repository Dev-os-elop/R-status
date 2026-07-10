// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ESStatus",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ESStatus", targets: ["ESStatus"])
    ],
    targets: [
        .executableTarget(
            name: "ESStatus",
            path: "Sources/ESStatus"
        )
    ]
)
