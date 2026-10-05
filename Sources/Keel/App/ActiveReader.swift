import AppKit
import Combine

/// The reader in the main window, for menu commands.
///
/// Document windows are AppKit windows hosting SwiftUI, so this follows the main window through
/// AppKit rather than relying on SwiftUI focused values. It also republishes the reader's and its
/// viewer's changes, so menu titles and enabled states stay current.
@MainActor
final class ActiveReader: ObservableObject {
  static let shared = ActiveReader()

  /// The main window's reader, or nil when no ready reader window is main.
  var model: ReaderViewModel? {
    guard let candidate, candidate.accessState == .ready else {
      return nil
    }
    return candidate
  }

  @Published private var candidate: ReaderViewModel?
  private var windowObservers: [NSObjectProtocol] = []
  private var modelObservers: Set<AnyCancellable> = []

  private init() {
    let names = [
      NSWindow.didBecomeMainNotification,
      NSWindow.didResignMainNotification,
      NSWindow.willCloseNotification,
    ]
    windowObservers = names.map { name in
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
        // Defer until AppKit has finished updating the main window.
        Task { @MainActor in
          ActiveReader.shared.update()
        }
      }
    }
  }

  private func update() {
    let current = (NSDocumentController.shared.currentDocument as? KeelDocument)?.readerViewModel
    guard current !== candidate else {
      return
    }
    modelObservers = []
    if let current {
      for publisher in [current.objectWillChange, current.viewer.objectWillChange] {
        publisher
          .sink { [weak self] _ in
            self?.objectWillChange.send()
          }
          .store(in: &modelObservers)
      }
    }
    candidate = current
  }
}
