// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nexio",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        .library(name: "Nexio", targets: ["Nexio"])
    ],
    targets: [
        .target(
            name: "Nexio",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "NexioTests",
            dependencies: ["Nexio"]
        )
    ]
)
