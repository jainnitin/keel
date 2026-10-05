import AppKit
import KeelCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationWillFinishLaunching(_ notification: Notification) {
    NSWindow.allowsAutomaticWindowTabbing = false
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    DispatchQueue.main.async {
      guard
        NSDocumentController.shared.documents.isEmpty,
        NSApplication.shared.windows.allSatisfy({ !$0.isVisible })
      else {
        return
      }
      WelcomeWindowController.shared.show()
    }
  }

  // Implementing this routes Finder and `open` file requests here instead of to
  // NSDocumentController, so file URLs must be opened explicitly.
  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      if url.isFileURL {
        DocumentOpener.open(url)
      } else if let link = PageLink(url: url) {
        DocumentOpener.open(link)
      } else {
        NSSound.beep()
      }
    }
  }

  func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      WelcomeWindowController.shared.show()
    }
    return false
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }
}

