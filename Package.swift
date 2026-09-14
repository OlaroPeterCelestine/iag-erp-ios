// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ErpIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ErpCore", targets: ["ErpCore"]),
    ],
    targets: [
        .target(name: "ErpCore"),
        .testTarget(name: "ErpCoreTests", dependencies: ["ErpCore"]),
    ]
)
