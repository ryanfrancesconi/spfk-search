// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-search",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "SPFKSearch",
            targets: ["SPFKSearch"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-base", from: "1.2.2"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "1.1.0"),
        .package(url: "https://github.com/ordo-one/FuzzyMatch.git", from: "1.4.0"),

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
