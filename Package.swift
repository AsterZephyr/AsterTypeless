// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AsterTypeless",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "AsterTypeless",
            targets: ["AsterTypeless"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "AsterTypeless",
            path: "Sources/AsterTypeless"
        ),
        .testTarget(
            name: "AsterTypelessTests",
            dependencies: ["AsterTypeless"],
            path: "Tests/AsterTypelessTests"
        ),
    ]
)
