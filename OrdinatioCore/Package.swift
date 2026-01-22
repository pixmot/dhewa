// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrdinatioCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OrdinatioCore",
            targets: ["OrdinatioCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.2.3"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OrdinatioCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "OrdinatioCoreTests",
            dependencies: [
                "OrdinatioCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
