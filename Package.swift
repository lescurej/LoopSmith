// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SeamlessLooper",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "SeamlessLooper", targets: ["SeamlessLooper"])
    ],
    dependencies: [
        // Ajoute ici AudioKit si besoin plus tard
    ],
    targets: [
        .executableTarget(
            name: "SeamlessLooper",
            dependencies: [],
            path: "SeamlessLooper"
        )
    ]
) 