// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Priority",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "Priority", targets: ["Priority"])
    ],
    targets: [
        .target(name: "Priority"),
        .testTarget(name: "PriorityTests", dependencies: ["Priority"]),
    ]
)
