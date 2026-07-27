// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MacSmoothScroll",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacSmoothScroll", targets: ["MacSmoothScroll"]),
        .executable(name: "MacSmoothScrollLauncher", targets: ["MacSmoothScrollLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "MacSmoothScroll",
            path: "Sources/MacSmoothScroll"
        ),
        .executableTarget(
            name: "MacSmoothScrollLauncher",
            path: "Sources/MacSmoothScrollLauncher"
        ),
        .testTarget(
            name: "MacSmoothScrollTests",
            dependencies: ["MacSmoothScroll", "MacSmoothScrollLauncher"],
            path: "Tests/MacSmoothScrollTests"
        )
    ]
)
