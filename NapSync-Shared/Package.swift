// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NapSync-Shared",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "NapSyncShared",
            targets: ["NapSyncShared"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NapSyncShared",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "NapSyncSharedTests",
            dependencies: ["NapSyncShared"],
            path: "Tests"
        ),
    ]
)