// swift-tools-version:5.9

import PackageDescription
import Foundation

let products: [Product] = [
    .library(
        name: "SwiftTerm",
        targets: ["SwiftTerm"]
    ),
]

let targets: [Target] = [
    .target(
        name: "SwiftTerm",
        dependencies: [],
        path: "Sources/SwiftTerm",
        exclude: ["Mac/README.md"],
        resources: [
            .process("Apple/Metal/Shaders.metal")
        ]
    )
]

let package = Package(
    name: "SwiftTerm",
    platforms: [
        .macOS(.v11)
    ],
    products: products,
    dependencies: [],
    targets: targets,
    swiftLanguageVersions: [.v5]
)
