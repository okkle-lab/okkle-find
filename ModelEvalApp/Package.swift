// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ModelEvalApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ModelEvalApp", targets: ["ModelEvalApp"])
    ],
    targets: [
        .executableTarget(
            name: "ModelEvalApp",
            path: "Sources/ModelEvalApp"
        )
    ]
)
