// swift-tools-version: 5.9

import AppleProductTypes
import PackageDescription

// Runnable iOS demo app for Nexio. Open this folder in Xcode (or double-click
// it in Finder) and pick an iPhone/iPad simulator — no .xcodeproj required.
let package = Package(
    name: "NexioExample",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "NexioExample",
            targets: ["AppModule"],
            bundleIdentifier: "com.nexio.example",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .lightningBolt),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight]
        )
    ],
    dependencies: [
        // Local dependency on the Nexio package this Example lives inside.
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "Nexio", package: "Nexio")
            ],
            path: "."
        )
    ]
)
