// swift-tools-version: 6.1

// Builds and tests only the platform-independent core. The macOS app is built
// from Keel.xcodeproj, which provides the bundle, Info.plist, and sandbox.
import PackageDescription

let package = Package(
  name: "Keel",
  platforms: [
    .macOS("26.0")
  ],
  products: [
    .library(name: "KeelCore", targets: ["KeelCore"])
  ],
  targets: [
    .target(
      name: "KeelCore",
      path: "Sources/KeelCore"
    ),
    .testTarget(
      name: "KeelCoreTests",
      dependencies: ["KeelCore"],
      path: "Tests/KeelCoreTests"
    ),
  ]
)
