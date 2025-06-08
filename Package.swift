// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "LoopSmith",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LoopSmith", targets: ["LoopSmith"])
    ],
    dependencies: [
        // Ajoute ici AudioKit si besoin plus tard
    ],
    targets: [
        .executableTarget(
            name: "LoopSmith",
            dependencies: [],
            path: "LoopSmith"
        )
    ]
)
