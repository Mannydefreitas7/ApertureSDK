// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApertureSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApertureSDK",
            targets: ["ApertureSDK"]),
        .library(
            name: "VideoEditorCore",
            targets: ["VideoEditorCore"]),
        .library(
            name: "VideoEditorEngine",
            targets: ["VideoEditorEngine"]),
        .library(
            name: "VideoEditorExport",
            targets: ["VideoEditorExport"]),
        .library(
            name: "VideoEditorSwiftUI",
            targets: ["VideoEditorSwiftUI"]),
        .library(
            name: "VideoEditorAssets",
            targets: ["VideoEditorAssets"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApertureSDK"),
        .target(
            name: "VideoEditorCore"),
        .target(
            name: "VideoEditorEngine",
            dependencies: ["VideoEditorCore"]),
        .target(
            name: "VideoEditorExport",
            dependencies: ["VideoEditorCore", "VideoEditorEngine"]),
        .target(
            name: "VideoEditorSwiftUI",
            dependencies: ["VideoEditorCore", "VideoEditorEngine", "VideoEditorExport"]),
        .target(
            name: "VideoEditorAssets",
            dependencies: ["VideoEditorCore"],
            resources: [.process("Resources")]),
        .testTarget(
            name: "ApertureSDKTests",
            dependencies: ["ApertureSDK"]),
    ]
)
