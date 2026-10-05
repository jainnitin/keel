<p align="center">
  <img src="Sources/Keel/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png" width="128" alt="Keel app icon">
</p>

<h1 align="center">Keel</h1>

<p align="center">A focused, native, read-only PDF reader for Mac</p>

<p align="center">
  <a href="https://github.com/jainnitin/keel/actions/workflows/ci.yml"><img src="https://github.com/jainnitin/keel/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/jainnitin/keel/releases/latest"><img src="https://img.shields.io/github/v/release/jainnitin/keel?label=download" alt="Download"></a>
</p>

A focused, native, read-only PDF reader for Apple-silicon Macs, built with SwiftUI and PDFKit.

Keel never edits, annotates, decrypts to disk, or saves over the source PDF.

## Features

- One window per document; open from Finder, **File › Open**, **Open Recent**, drag and drop, or the welcome window
- Continuous, single-page, and two-page layouts (with an optional separate cover), zoom, fit to width, page entry
- Native full screen and an optional Dark Pages mode for night reading
- Sidebar with page thumbnails, table of contents, and search results
- Password-protected PDFs, with optional Keychain storage per document
- Print through the standard print panel, and share the original PDF with AirDrop, Mail, Messages, and other services
- Reading position, zoom, layout, and sidebar state restored per document

## Requirements

- Apple-silicon Mac running macOS 26 or later
- Xcode 26 or later (Command Line Tools alone cannot build the app)

## Build and run

Open `Keel.xcodeproj`, select the **Keel** scheme and **My Mac**, then **Product › Run**.

From the command line:

```sh
xcodebuild -project Keel.xcodeproj -scheme Keel \
  -destination 'platform=macOS,arch=arm64' build   # or: test
```

If `xcode-select -p` points at Command Line Tools, run `sudo xcode-select -s /Applications/Xcode.app`
or prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The Swift package covers only `KeelCore`, for quick pure-logic builds and tests:

```sh
swift build
swift test
```

## Project layout

```text
Sources/Keel/         macOS app: AppKit/SwiftUI UI, PDFKit, Keychain
Sources/KeelCore/     Pure logic with no UI dependencies: identity, reader state, search excerpts, text-layer sampling
Tests/KeelCoreTests/  Unit tests for KeelCore
Keel/                 Info.plist and sandbox entitlements
```

See [AGENTS.md](AGENTS.md) for architecture notes and conventions.
