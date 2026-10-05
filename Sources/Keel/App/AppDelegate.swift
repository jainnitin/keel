import AppKit

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

  func applicationWillTerminate(_ notification: Notification) {
    // Documents aren't closed on quit, so write any reading position still waiting to be saved.
    for case let document as KeelDocument in NSDocumentController.shared.documents {
      document.readerViewModel?.flushPendingSave()
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

