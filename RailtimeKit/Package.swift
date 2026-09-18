// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RailtimeKit",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LTAAPI",
            targets: ["LTAAPI"]
        ),
        .library(
            name: "BusEstimation",
            targets: ["BusEstimation"]
        ),
        .library(
            name: "Journey",
            targets: ["Journey"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/weichsel/ZIPFoundation.git",
            from: "0.9.0"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LTAAPI",
            dependencies: ["ZIPFoundation"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "BusEstimation",
            dependencies: ["LTAAPI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "Journey",
            dependencies: ["BusEstimation", "LTAAPI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
