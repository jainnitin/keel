# Keel

[![CI](https://github.com/jainnitin/keel/actions/workflows/ci.yml/badge.svg)](https://github.com/jainnitin/keel/actions/workflows/ci.yml)

A focused, native, read-only PDF reader for Apple-silicon Macs, built with SwiftUI and PDFKit.

Keel never edits, annotates, decrypts to disk, or saves over the source PDF.

## Features

- One window per document; open from Finder, **File › Open**, **Open Recent**, drag and drop, or the welcome window
- Continuous or single-page layout, zoom, fit to width, page entry
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
Sources/KeelCore/     Pure logic with no UI dependencies: identity, reader state, search excerpts
Tests/KeelCoreTests/  Unit tests for KeelCore
Keel/                 Info.plist and sandbox entitlements
```

See [AGENTS.md](AGENTS.md) for architecture notes and conventions.
