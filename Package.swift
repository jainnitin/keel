// swift-tools-version: 6.1

// Builds and tests only the platform-independent core. The macOS app is built
// from LeafPDF.xcodeproj, which provides the bundle, Info.plist, and sandbox.
import PackageDescription

let package = Package(
  name: "LeafPDF",
  platforms: [
    .macOS("26.0")
  ],
  products: [
    .library(name: "LeafPDFCore", targets: ["LeafPDFCore"])
  ],
  targets: [
    .target(
      name: "LeafPDFCore",
      path: "Sources/LeafPDFCore"
    ),
    .testTarget(
      name: "LeafPDFCoreTests",
      dependencies: ["LeafPDFCore"],
      path: "Tests/LeafPDFCoreTests"
    ),
  ]
)
