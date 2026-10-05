# Leaf PDF

A focused, native, read-only PDF reader for Apple-silicon Macs, built with SwiftUI and PDFKit.

Leaf PDF never edits, annotates, decrypts to disk, or saves over the source PDF.

## Features

- One window per document; open from Finder, **File › Open**, **Open Recent**, drag and drop, or the welcome window
- Continuous or single-page layout, zoom, fit to width, page entry
- Sidebar with page thumbnails, table of contents, and search results
- Password-protected PDFs, with optional Keychain storage per document
- Reading position, zoom, layout, and sidebar state restored per document

## Requirements

- Apple-silicon Mac running macOS 26 or later
- Xcode 26 or later (Command Line Tools alone cannot build the app)

## Build and run

Open `LeafPDF.xcodeproj`, select the **LeafPDF** scheme and **My Mac**, then **Product › Run**.

From the command line:

```sh
xcodebuild -project LeafPDF.xcodeproj -scheme LeafPDF \
  -destination 'platform=macOS,arch=arm64' build   # or: test
```

If `xcode-select -p` points at Command Line Tools, run `sudo xcode-select -s /Applications/Xcode.app`
or prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The Swift package covers only `LeafPDFCore`, for quick pure-logic builds and tests:

```sh
swift build
swift test
```

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Open | `⌘O` |
| Welcome window | `⇧⌘1` |
| Previous / next page | `Page Up` / `Page Down` |
| Zoom in / out | `⌘+` / `⌘-` |
| Actual size | `⌘0` |
| Fit to width | `⌘9` |
| Toggle sidebar | `⌃⌘S` |

## Project layout

```text
Sources/LeafPDF/       macOS app: AppKit/SwiftUI UI, PDFKit, Keychain
Sources/LeafPDFCore/   Pure logic with no UI dependencies: identity, reader state, search excerpts
Tests/LeafPDFCoreTests/ Unit tests for LeafPDFCore
LeafPDF/               Info.plist and sandbox entitlements
Tools/                 App icon generator
```

See [AGENTS.md](AGENTS.md) for architecture notes and conventions.

To regenerate the app icon after changing its drawing code:

```sh
swift Tools/generate_app_icon.swift \
  Sources/LeafPDF/Resources/Assets.xcassets/AppIcon.appiconset
```
