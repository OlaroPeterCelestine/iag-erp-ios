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
        .target(name: "ErpCore", resources: [.process("FormSpecs.json")]),
        // App sources live in the Xcode target. This target exists so SourceKit
        // can resolve `import ErpCore` when the folder is opened outside Xcode.
        .executableTarget(
            name: "ErpApp",
            dependencies: ["ErpCore"],
            path: "App",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "LaunchScreen.storyboard",
            ]
        ),
        .testTarget(name: "ErpCoreTests", dependencies: ["ErpCore"]),
    ]
)
