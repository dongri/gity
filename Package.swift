// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GitY",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GitY", targets: ["GitY"])
    ],
    dependencies: [
        .package(url: "https://github.com/eastriverlee/LLM.swift", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "GitY",
            dependencies: [
                .product(name: "LLM", package: "LLM.swift")
            ],
            path: "Sources",
            resources: [
                .copy("../Resources/Assets.xcassets")
            ]
        )
    ]
)
