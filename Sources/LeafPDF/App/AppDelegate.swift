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
      NSDocumentController.shared.openDocument(nil)
    }
  }

  func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
    false
  }

  func application(_ application: NSApplication, openFiles filenames: [String]) {
    let urls = filenames.map(URL.init(fileURLWithPath:))
    guard !urls.isEmpty else {
      application.reply(toOpenOrPrint: .failure)
      return
    }
    open(urls, at: 0, application: application, firstError: nil)
  }

  private func open(
    _ urls: [URL],
    at index: Int,
    application: NSApplication,
    firstError: Error?
  ) {
    guard index < urls.count else {
      application.reply(toOpenOrPrint: firstError == nil ? .success : .failure)
      if let firstError {
        application.presentError(firstError)
      }
      return
    }

    NSDocumentController.shared.openDocument(
      withContentsOf: urls[index],
      display: true
    ) { [weak self] _, _, error in
      Task { @MainActor [weak self] in
        self?.open(
          urls,
          at: index + 1,
          application: application,
          firstError: firstError ?? error
        )
      }
    }
  }
}
