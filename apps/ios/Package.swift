// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BeamDropIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BeamDropIOSCore", targets: ["BeamDropIOSCore"])
    ],
    targets: [
        .target(name: "BeamDropIOSCore"),
        .testTarget(
            name: "BeamDropIOSCoreTests",
            dependencies: ["BeamDropIOSCore"]
        )
    ]
)
