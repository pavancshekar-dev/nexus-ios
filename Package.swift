// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NexusChat",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "NexusChat", targets: ["NexusChat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", branch: "main"),
    ],
    targets: [
        .target(
            name: "NexusChat",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "NexusChat"
        ),
    ]
)
