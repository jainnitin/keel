# Leaf PDF

Leaf PDF is a focused, native PDF reader for Apple-silicon Macs. It uses SwiftUI for the macOS app shell and PDFKit’s `PDFView` for rendering, selection, links, navigation, and embedded-text search.

The app is deliberately read-only: it never removes encryption, exports decrypted copies, edits or annotates content, manipulates pages, or saves over the source PDF.

## Highlights

- Native one-document-per-window lifecycle with Finder **Open With**, **Open**, **Open Recent**, drag and drop, and window restoration
- Continuous vertical reading and optional single-page layout
- Native toolbar controls for page navigation, page entry, zoom, actual size, fit to width, layout, search, and sidebar visibility
- Lazy, cancellable thumbnails with a bounded cost-aware cache
- PDF outline/table of contents and PDFKit embedded-text search with contextual results
- Text selection, copying, clickable links, keyboard navigation, trackpad scrolling, accessibility labels, tooltips, and native focus behavior
- Password-protected PDFs with stable document identity and optional macOS Keychain storage
- Automatic stale-password removal plus a per-document **Forget Saved Password** command
- Explicit errors for inaccessible or malformed files, unsupported encryption, Keychain failures, thumbnail failures, and reading-state persistence failures
- Native system typography, SF Symbols, materials, semantic colors, and toolbar/sidebar behavior that adapt to appearance, increased contrast, and reduced transparency

## Requirements

- Apple-silicon Mac
- macOS 26 or later
- Xcode 26 or later with the macOS 26 SDK
- Swift 6

Command Line Tools alone are not sufficient because the app target requires Xcode’s SwiftUI macro, asset catalog, XCTest, and app-bundling toolchain.

## Build and run

1. Open `LeafPDF.xcodeproj` in Xcode.
2. Select the **LeafPDF** scheme and **My Mac** destination.
3. Choose **Product > Run**.
4. Open a PDF with **File > Open**, drag one onto a Leaf PDF window, or choose Leaf PDF from Finder’s **Open With** menu.

Command-line validation with a full Xcode installation:

```sh
xcodebuild \
  -project LeafPDF.xcodeproj \
  -scheme LeafPDF \
  -destination 'platform=macOS,arch=arm64' \
  test

xcodebuild \
  -project LeafPDF.xcodeproj \
  -scheme LeafPDF \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

The Swift package manifest also exposes `LeafPDFCore` for focused pure-logic builds and tests:

```sh
swift build --product LeafPDFCore
swift test --filter LeafPDFCoreTests
```

## Keyboard controls

| Action | Shortcut |
| --- | --- |
| Open | `⌘O` |
| Find | `⌘F` |
| Previous / next page | `Page Up` / `Page Down` |
| Zoom in / out | `⌘+` / `⌘-` |
| Actual size | `⌘0` |
| Fit to width | `⌘9` |
| Toggle sidebar | `⌃⌘S` |

Standard PDFKit and macOS selection, copy, link, scrolling, focus, and window shortcuts remain available.

## Architecture

```text
LeafPDFDocument (NSDocument)
├── authoritative, file-URL-backed PDFDocument
├── stable DocumentIdentity
└── ReaderViewModel
    ├── PDFViewController / PDFViewRepresentable
    ├── PDFSearchService (PDFDocumentDelegate)
    ├── ThumbnailService actor (CGPDFDocument renderer + bounded LRU cache)
    ├── PasswordCoordinator → KeychainPasswordStore actor
    └── ReaderStateStore (bounded UserDefaults persistence)
```

- `LeafPDFDocument` is the sole owner of the window’s authoritative `PDFDocument`.
- The `PDFViewController` is a small adapter for navigation, layout, zoom, notifications, and teardown.
- Search uses PDFKit’s asynchronous document find API; v1 intentionally does not perform OCR.
- Thumbnail rendering uses a separate read-only Core Graphics handle to avoid retaining `PDFPage` objects or rendering on the main actor. Cache entries are bounded by both count and decoded byte cost.
- Search, thumbnail, unlock, observer, and state-save work is cancelled or detached when the document closes.
- Passwords are addressed by a SHA-256 document identity derived from the volume and file resource identifiers, with path/size/creation-date fallback when stable identifiers are unavailable.
- Keychain values use `kSecAttrAccessibleWhenUnlocked`; passwords are never logged or persisted outside Keychain.
- Reader state is normalized and capped to the 50 most recently used documents.

## Project structure

```text
Sources/LeafPDF/          AppKit, SwiftUI, PDFKit, Security, and UI services
Sources/LeafPDFCore/      Pure document identity, password abstraction, search, and reader state
Tests/LeafPDFCoreTests/   Unit and regression tests
Tools/                    Maintainable app-icon generator
LeafPDF/                  Info.plist and sandbox entitlements
```

The app sandbox grants only user-selected read access. Leaf PDF has no network dependency and uses Apple frameworks exclusively.
