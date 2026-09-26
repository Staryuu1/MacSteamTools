// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MacSteamTools", platforms: [.macOS(.v13)], products: [.executable(name: "MacSteamTools", targets: ["MacSteamTools"])], targets: [.executableTarget(name: "MacSteamTools")])
