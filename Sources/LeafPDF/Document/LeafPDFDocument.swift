import AppKit
import CoreGraphics
import LeafPDFCore
import PDFKit
import SwiftUI

@MainActor
final class LeafPDFDocument: NSDocument {
  nonisolated(unsafe) private(set) var pdfDocument: PDFDocument?
  nonisolated(unsafe) private(set) var documentIdentity: DocumentIdentity?
  private var readerViewModel: ReaderViewModel?

  override class var autosavesInPlace: Bool {
    false
  }

  override var isDocumentEdited: Bool {
    false
  }

  override func read(from url: URL, ofType typeName: String) throws {
    let identity: DocumentIdentity
    do {
      identity = try DocumentIdentity.resolve(url: url)
    } catch {
      throw LeafPDFDocumentError.inaccessible(url, underlying: error)
    }

    guard let document = PDFDocument(url: url) else {
      if let quartzDocument = CGPDFDocument(url as CFURL), quartzDocument.isEncrypted {
        throw LeafPDFDocumentError.unsupportedEncryption(url)
      }
      throw LeafPDFDocumentError.malformed(url)
    }
    guard document.isLocked || document.pageCount > 0 else {
      throw LeafPDFDocumentError.malformed(url)
    }

    pdfDocument = document
    documentIdentity = identity
    fileURL = url
  }

  override func makeWindowControllers() {
    guard
      let pdfDocument,
      let documentIdentity,
      let fileURL
    else {
      return
    }

    let viewModel = ReaderViewModel(
      document: pdfDocument,
      identity: documentIdentity,
      sourceURL: fileURL
    )
    readerViewModel = viewModel

    let hostingController = NSHostingController(
      rootView: ReaderRootView(model: viewModel)
    )
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1_080, height: 760),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.contentViewController = hostingController
    window.title = displayName
    window.titleVisibility = .visible
    window.titlebarSeparatorStyle = .automatic
    window.toolbarStyle = .unified
    window.tabbingMode = .disallowed
    window.isRestorable = true
    let frameAutosaveName = "LeafPDF.DocumentWindow"
    let restoredFrame = window.setFrameUsingName(frameAutosaveName)
    window.setFrameAutosaveName(frameAutosaveName)
    if !restoredFrame {
      window.center()
    }

    let windowController = NSWindowController(window: window)
    addWindowController(windowController)
  }

  override func close() {
    readerViewModel?.tearDown()
    readerViewModel = nil
    pdfDocument?.delegate = nil
    pdfDocument = nil
    super.close()
  }
}

enum LeafPDFDocumentError: LocalizedError {
  case inaccessible(URL, underlying: Error)
  case malformed(URL)
  case unsupportedEncryption(URL)

  var errorDescription: String? {
    switch self {
    case .inaccessible(let url, _):
      "“\(url.lastPathComponent)” could not be accessed."
    case .malformed(let url):
      "“\(url.lastPathComponent)” is not a valid PDF or is corrupted."
    case .unsupportedEncryption(let url):
      "“\(url.lastPathComponent)” uses PDF encryption that this version of macOS cannot open."
    }
  }

  var failureReason: String? {
    switch self {
    case .inaccessible(_, let underlying):
      underlying.localizedDescription
    case .malformed:
      "PDFKit could not read the document structure."
    case .unsupportedEncryption:
      "The document is encrypted, but PDFKit cannot decode its encryption format."
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .inaccessible:
      "Check the file’s permissions and location, then try again."
    case .malformed:
      "Try opening a known-good copy of the PDF."
    case .unsupportedEncryption:
      "Ask the document owner for a PDF using a supported encryption format."
    }
  }
}
