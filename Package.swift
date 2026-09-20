// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "siri-say",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "siri-say", targets: ["SiriSay"])
    ],
    targets: [
        .executableTarget(name: "SiriSay", path: "Sources/SiriSay")
    ]
)
