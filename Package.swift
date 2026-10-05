// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "LeafPDF",
  platforms: [
    .macOS("26.0")
  ],
  products: [
    .library(name: "LeafPDFCore", targets: ["LeafPDFCore"]),
    .executable(name: "LeafPDF", targets: ["LeafPDF"]),
  ],
  targets: [
    .target(
      name: "LeafPDFCore",
      path: "Sources/LeafPDFCore"
    ),
    .executableTarget(
      name: "LeafPDF",
      dependencies: ["LeafPDFCore"],
      path: "Sources/LeafPDF",
      exclude: ["Resources"],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("PDFKit"),
        .linkedFramework("Security"),
      ]
    ),
    .testTarget(
      name: "LeafPDFCoreTests",
      dependencies: ["LeafPDFCore"],
      path: "Tests/LeafPDFCoreTests"
    ),
  ]
)
