// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusBlock",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "FocusBlockCore",
            targets: ["FocusBlockCore"]),
        .executable(
            name: "focus",
            targets: ["FocusCLI"]),
        .executable(
            name: "focus-daemon",
            targets: ["FocusDaemon"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "FocusBlockCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]),
        .executableTarget(
            name: "FocusCLI",
            dependencies: [
                "FocusBlockCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .executableTarget(
            name: "FocusDaemon",
            dependencies: [
                "FocusBlockCore",
            ]),
        .testTarget(
            name: "FocusBlockCoreTests",
            dependencies: ["FocusBlockCore"]),
    ]
)
