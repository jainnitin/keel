import AppKit
import KeelCore
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

  /// Opens a `keel://` page link, reusing the document's window when it's already open.
  static func open(_ link: PageLink) {
    let fileURL = link.fileURL.standardizedFileURL
    let openDocument = NSDocumentController.shared.documents.first {
      $0.fileURL?.standardizedFileURL == fileURL
    }
    if let document = openDocument as? KeelDocument {
      document.showWindows()
      show(link, in: document)
      return
    }

    NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) {
      document, _, error in
      if let document = document as? KeelDocument {
        show(link, in: document)
      } else if let error {
        if isPermissionError(error) {
          requestAccess(for: link)
        } else {
          NSApplication.shared.presentError(error)
        }
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

  private static func show(_ link: PageLink, in document: KeelDocument) {
    if let pageNumber = link.pageNumber {
      document.showPage(number: pageNumber)
    }
  }

  /// The sandbox grants access only to files the user chose, so a link to any other file
  /// fails; asking the user to pick it in an Open panel grants access.
  private static func requestAccess(for link: PageLink) {
    let panel = NSOpenPanel()
    panel.message = "Keel needs permission to open “\(link.fileURL.lastPathComponent)”."
    panel.prompt = "Open"
    panel.allowedContentTypes = [.pdf]
    panel.allowsMultipleSelection = false
    // A file URL as the directory opens the panel in its folder with the file selected.
    panel.directoryURL = link.fileURL
    panel.begin { response in
      guard response == .OK, let url = panel.url else {
        return
      }
      open(PageLink(fileURL: url, pageNumber: link.pageNumber))
    }
  }

  private static func isPermissionError(_ error: Error) -> Bool {
    switch error {
    case KeelDocumentError.inaccessible(_, let underlying):
      return isPermissionError(underlying)
    case DocumentIdentityError.unreadable:
      return true
    default:
      let nsError = error as NSError
      switch (nsError.domain, nsError.code) {
      case (NSCocoaErrorDomain, NSFileReadNoPermissionError),
        (NSPOSIXErrorDomain, Int(EPERM)),
        (NSPOSIXErrorDomain, Int(EACCES)):
        return true
      default:
        return (nsError.userInfo[NSUnderlyingErrorKey] as? Error).map(isPermissionError) ?? false
      }
    }
  }
}
