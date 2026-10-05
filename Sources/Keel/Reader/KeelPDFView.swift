import PDFKit

/// A PDFView that goes back and forward through its history with the mouse's side buttons,
/// as in a web browser.
final class KeelPDFView: PDFView {
  private enum MouseButton {
    static let back = 3
    static let forward = 4
  }

  override func otherMouseUp(with event: NSEvent) {
    switch event.buttonNumber {
    case MouseButton.back where canGoBack:
      goBack(nil)
    case MouseButton.forward where canGoForward:
      goForward(nil)
    default:
      super.otherMouseUp(with: event)
    }
  }
}
