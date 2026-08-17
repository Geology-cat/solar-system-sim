// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "SolarSystemSim",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "SolarSystemSim",
            targets: ["SolarSystemSim"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SolarSystemSim",
            path: ".",
            exclude: [
                "icon_generator.swift",
                "verify_positions.swift",
                "sierra ver",
                "SolarSystemSim.app",
                "AppIcon.iconset",
                "icon.png",
                "UserGuide.html",
                "技術解説.html"
            ]
        )
    ]
)
