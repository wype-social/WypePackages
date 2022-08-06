// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WypePackages",
    defaultLocalization: "en",
    platforms: [.iOS(.v15), .macCatalyst(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ActiveLabel",
            targets: ["ActiveLabel"]),
        .library(
            name: "Hover",
            targets: ["Hover"]),
        .library(
            name: "PanModal",
            targets: ["PanModal"]),
        .library(
            name: "SPIndicator",
            targets: ["SPIndicator"]),
        .library(
            name: "SwiftyOnboard",
            targets: ["SwiftyOnboard"]),
        .library(
            name: "VideoCompressor",
            targets: ["VideoCompressor"]),
        .library(
            name: "ZLPhotoBrowser",
            targets: ["ZLPhotoBrowser"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ActiveLabel",
            dependencies: []),
        .target(
            name: "Hover",
            dependencies: []),
        .target(
            name: "PanModal",
            dependencies: []),
        .target(
            name: "SPIndicator",
            dependencies: []),
        .target(
            name: "SwiftyOnboard",
            dependencies: []),
        .target(
            name: "VideoCompressor",
            dependencies: []),
        .target(
            name: "ZLPhotoBrowser",
            dependencies: [],
            resources: [.copy("ZLPhotoBrowser.bundle")]
        ),
    ]
)
