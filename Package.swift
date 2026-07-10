// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LiveWallpapers",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LiveWallpapers",
            targets: ["LiveWallpapers"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "LiveWallpapers",
            path: "Sources/LiveWallpapers",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "LiveWallpapersTests",
            dependencies: ["LiveWallpapers"]
        ),
    ]
)
