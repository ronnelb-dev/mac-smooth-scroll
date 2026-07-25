// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MacSmoothScroll",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacSmoothScroll", targets: ["MacSmoothScroll"])
    ],
    targets: [
        .executableTarget(
            name: "MacSmoothScroll",
            path: "Sources/MacSmoothScroll"
        )
    ]
)
