// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BeamDropMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BeamDropMacCore", targets: ["BeamDropMacCore"]),
        .executable(name: "BeamDropMacApp", targets: ["BeamDropMacApp"])
    ],
    targets: [
        .target(name: "BeamDropMacCore"),
        .executableTarget(
            name: "BeamDropMacApp",
            dependencies: ["BeamDropMacCore"]
        ),
        .testTarget(
            name: "BeamDropMacCoreTests",
            dependencies: ["BeamDropMacCore"]
        )
    ]
)
