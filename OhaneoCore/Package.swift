// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OhaneoCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "OhaneoCore", targets: ["OhaneoCore"]),
    ],
    targets: [
        .target(
            name: "OhaneoCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "OhaneoCoreTests",
            dependencies: ["OhaneoCore"]
        ),
    ]
)
