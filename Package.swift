// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypelessMac",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "TypelessMacApp",
            targets: ["TypelessMacApp"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "TypelessMacApp",
            path: "Sources/TypelessMacApp"
        ),
    ]
)
