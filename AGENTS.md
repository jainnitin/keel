# Agent notes

Notes for anyone (human or agent) changing this codebase. Keep this file short and current.

## Build and verify

- The app builds only with full Xcode. If `xcode-select -p` shows Command Line Tools, prefix commands
  with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Build and test: `xcodebuild -project Keel.xcodeproj -scheme Keel -destination 'platform=macOS,arch=arm64' test`
- `Package.swift` builds only `KeelCore`. A passing `swift build` says nothing about the app.
- The Xcode project uses folder-synchronized groups: new files under `Sources/Keel`,
  `Sources/KeelCore`, or `Tests/KeelCoreTests` are picked up automatically. Don't add
  per-file entries to `project.pbxproj`.
- Manual testing: launch with `--args -ApplePersistenceIgnoreState YES` to skip window restoration
  (otherwise previously open PDFs reopen and the welcome window stays hidden). When relaunching,
  wait for the old process to exit first; `open` sent to a terminating instance does nothing.
- To test sandbox behavior, run the app from an `xcodebuild build`: a `test` build adds a read-anywhere
  exception for the test host. Each rebuild re-signs the app, which drops its Open Recent access.
- Tests cover `KeelCore` only. UI changes need a manual check in the running app.

## Architecture

- `KeelDocument` (NSDocument) owns the `PDFDocument` and builds one window per document, hosting
  `ReaderRootView`. `NSDocumentController` handles opening from Finder, the Open panel, and Recents.
- `ReaderViewModel` is the per-window state: access/unlock flow, sidebar and search state, and
  debounced persistence of `ReaderState`. Call `tearDown()` when the document closes.
- `PDFViewController` is the only code that talks to `PDFView`; `PDFViewRepresentable` just attaches it.
- `ThumbnailService` (actor) renders with its own `CGPDFDocument` so it never touches PDFKit objects
  off the main actor. Encrypted PDFs must be unlocked on both the PDFKit and CoreGraphics documents.
- `WelcomeWindowController` is shown at launch and on Dock reopen when no document window is visible;
  it closes itself when a document window becomes main.
- `DocumentOpener` is the single place for opening URLs and filtering dropped files to PDFs.
  `AppDelegate.application(_:open:)` sends it both file URLs and `keel://` page links (`PageLink`
  in `KeelCore`); because that method exists, AppKit no longer opens files on its own.
- Put logic that doesn't need AppKit/PDFKit in `KeelCore` so it can be unit tested.

## Conventions

- Swift 6 strict concurrency. UI types are `@MainActor`. PDFKit types aren't `Sendable`; when a
  delegate or notification callback must hand one to the main actor, wrap it in a small private
  `@unchecked Sendable` struct (see `PDFSearchService`, `WelcomeWindowController`).
- The app is read-only and sandboxed with user-selected read access only. Don't add write paths,
  network access, or new entitlements without discussion.
- Passwords live only in Keychain (`KeychainPasswordStore`), never in logs or `UserDefaults`.
- Present user-facing errors through `ReaderViewModel.present(_:title:)` inside a document window,
  or `NSApplication.presentError` outside one.
- Two-space indentation; match the surrounding style. Prefer native macOS controls and SF Symbols.

## Workflow

- Several agents may push to `main`. Run `git pull --rebase` before starting, and rebase before pushing.
- Do work on a branch and open a PR. Run the Xcode build and tests before pushing.
