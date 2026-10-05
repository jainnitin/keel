import AppKit
import UniformTypeIdentifiers

@MainActor
enum DocumentOpener {
  static func open(_ url: URL) {
    NSDocumentController.shared.openDocument(withContentsOf: url, display: true) {
      _, _, error in
      if let error {
        NSApplication.shared.presentError(error)
      }
    }
  }

  /// Opens the PDFs among dropped URLs; returns whether any were found.
  @discardableResult
  static func openDroppedPDFs(_ urls: [URL]) -> Bool {
    let pdfs = urls.filter { url in
      (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.conforms(to: .pdf)
        ?? false
    }
    pdfs.forEach(open)
    return !pdfs.isEmpty
  }
}
