// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CommandGathering",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CommandGatheringCore", targets: ["CommandGatheringCore"]),
        .executable(name: "CommandGatheringApp", targets: ["CommandGatheringApp"])
    ],
    dependencies: [
        .package(path: "Vendor/SwiftTerm")
    ],
    targets: [
        .target(name: "CommandGatheringCore"),
        .executableTarget(
            name: "CommandGatheringApp",
            dependencies: [
                "CommandGatheringCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        ),
        .testTarget(
            name: "CommandGatheringCoreTests",
            dependencies: ["CommandGatheringCore"]
        )
    ]
)
