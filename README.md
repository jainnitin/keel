# Keel

A focused, native, read-only PDF reader for Apple-silicon Macs, built with SwiftUI and PDFKit.

Keel never edits, annotates, decrypts to disk, or saves over the source PDF.

## Features

- One window per document; open from Finder, **File › Open**, **Open Recent**, drag and drop, or the welcome window
- Continuous or single-page layout, zoom, fit to width, page entry
- Sidebar with page thumbnails, table of contents, and search results
- Password-protected PDFs, with optional Keychain storage per document
- Reading position, zoom, layout, and sidebar state restored per document
- Deep links to a page (`keel://`), with **Copy Link to Page** in the Document Options menu

## Deep links

```text
keel://open?file=<percent-encoded absolute path>&page=<page number>
```

`page` is 1-based and optional; numbers past the end open the last page. If the document is already
open, Keel brings its window forward and goes to the page. Because Keel is sandboxed, it can open
linked files from Open Recent directly; for any other file it asks you to confirm the file in an
Open panel first.

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
| Copy link to page | `⌥⌘C` |

## Project layout

```text
Sources/Keel/         macOS app: AppKit/SwiftUI UI, PDFKit, Keychain
Sources/KeelCore/     Pure logic with no UI dependencies: identity, reader state, search excerpts, page links
Tests/KeelCoreTests/  Unit tests for KeelCore
Keel/                 Info.plist and sandbox entitlements
```

See [AGENTS.md](AGENTS.md) for architecture notes and conventions.
