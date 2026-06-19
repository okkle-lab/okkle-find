// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PromptGradeApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PromptGradeApp", targets: ["PromptGradeApp"])
    ],
    targets: [
        .executableTarget(
            name: "PromptGradeApp",
            path: "Sources/PromptGradeApp"
        )
    ]
)
