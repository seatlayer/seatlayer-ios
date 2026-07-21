// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SeatLayer",
    // iOS 15 is the shipping target. macOS is declared only so the pure-Swift
    // bridge tests can run without a simulator; `SeatLayerView` is iOS-only.
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "SeatLayer", targets: ["SeatLayer"]),
    ],
    targets: [
        .target(
            name: "SeatLayer",
            // NOT named "Resources": that name collides with the reserved
            // directory in a generated resource bundle and the bundle then
            // fails to code-sign.
            resources: [.copy("Web")]
        ),
        .testTarget(
            name: "SeatLayerTests",
            dependencies: ["SeatLayer"]
        ),
    ]
)
