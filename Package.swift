// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GitY",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GitY", targets: ["GitY"])
    ],
    targets: [
        .executableTarget(
            name: "GitY",
            path: "Sources",
            resources: [
                .copy("../Resources/Assets.xcassets")
            ]
        )
    ]
)
