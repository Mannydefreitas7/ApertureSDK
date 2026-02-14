// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApertureSDK",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApertureSDK",
            targets: ["ApertureSDK"]),
        .library(
            name: "ApertureCore",
            targets: ["ApertureCore"]),
        .library(
            name: "ApertureEngine",
            targets: ["ApertureEngine"]),
        .library(
            name: "ApertureExport",
            targets: ["ApertureExport"]),
        .library(
            name: "ApertureUI",
            targets: ["ApertureUI"]),
        .library(
            name: "ApertureLib",
            targets: ["ApertureLib"]),
        .library(
            name: "ApertureAI",
            targets: ["ApertureAI"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApertureSDK",
            dependencies: [
                "ApertureCore",
                "ApertureEngine",
                "ApertureExport",
                "ApertureUI",
                "ApertureLib",
                "ApertureAI",
            ]),
        .target(
            name: "ApertureCore"),
        .target(
            name: "ApertureEngine",
            dependencies: ["ApertureCore"]),
        .target(
            name: "ApertureExport",
            dependencies: ["ApertureCore", "ApertureEngine"]),
        .target(
            name: "ApertureUI",
            dependencies: ["ApertureCore", "ApertureEngine", "ApertureExport"],
            exclude: ["iOS", "macOS"]),
        .target(
            name: "ApertureAssets",
            dependencies: ["ApertureCore"],
            resources: [.process("Resources")]),
        .target(
            name: "ApertureAI",
            dependencies: ["ApertureCore", "ApertureEngine"]),
        .testTarget(
            name: "ApertureSDKTests",
            dependencies: ["ApertureSDK"]),
        .testTarget(
            name: "VideoEditorCoreTests",
            dependencies: ["ApertureCore"]),
    ]
)
