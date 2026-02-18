// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-search",
    platforms: [.macOS(.v14), .iOS(.v26),],
    products: [
        .library(
            name: "SPFKSearch",
            targets: ["SPFKSearch"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-base", branch: "development"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", branch: "development"),
        .package(url: "https://github.com/ryanfrancesconi/FuzzyMatch.git", branch: "development"),

    ],
    targets: [
        .target(
            name: "SPFKSearch",
            dependencies: [
                .product(name: "SPFKBase", package: "spfk-base"),
                .product(name: "FuzzyMatch", package: "FuzzyMatch"),
            ],

        ),
        .testTarget(
            name: "SPFKSearchTests",
            dependencies: [
                .targetItem(name: "SPFKSearch", condition: nil),
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ]
        ),
    ]
)
