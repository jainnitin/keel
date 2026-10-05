import AppKit
import CoreGraphics
import KeelCore
import PDFKit
import SwiftUI

@MainActor
final class KeelDocument: NSDocument {
  nonisolated(unsafe) private(set) var pdfDocument: PDFDocument?
  nonisolated(unsafe) private(set) var documentIdentity: DocumentIdentity?
  private(set) var readerViewModel: ReaderViewModel?

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
      throw KeelDocumentError.inaccessible(url, underlying: error)
    }

    guard let document = PDFDocument(url: url) else {
      if let quartzDocument = CGPDFDocument(url as CFURL), quartzDocument.isEncrypted {
        throw KeelDocumentError.unsupportedEncryption(url)
      }
      throw KeelDocumentError.malformed(url)
    }
    guard document.isLocked || document.pageCount > 0 else {
      throw KeelDocumentError.malformed(url)
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
    window.collectionBehavior.insert(.fullScreenPrimary)
    window.isRestorable = true
    let frameAutosaveName = "Keel.DocumentWindow"
    let restoredFrame = window.setFrameUsingName(frameAutosaveName)
    window.setFrameAutosaveName(frameAutosaveName)
    if !restoredFrame {
      window.center()
    }

    let windowController = NSWindowController(window: window)
    addWindowController(windowController)
  }

  override func printOperation(
    withSettings printSettings: [NSPrintInfo.AttributeKey: Any]
  ) throws -> NSPrintOperation {
    guard let pdfDocument else {
      throw KeelDocumentError.printUnavailable("The document is no longer open.")
    }
    guard !pdfDocument.isLocked else {
      throw KeelDocumentError.printUnavailable("Unlock the document with its password before printing.")
    }
    let printInfo = (self.printInfo.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
    for (key, value) in printSettings {
      printInfo.dictionary()[key] = value
    }
    guard
      let operation = pdfDocument.printOperation(
        for: printInfo,
        scalingMode: .pageScaleDownToFit,
        autoRotate: true
      )
    else {
      throw KeelDocumentError.printUnavailable("PDFKit could not prepare the document for printing.")
    }
    operation.jobTitle = displayName
    return operation
  }

  override func close() {
    readerViewModel?.tearDown()
    readerViewModel = nil
    pdfDocument?.delegate = nil
    pdfDocument = nil
    super.close()
  }
}

enum KeelDocumentError: LocalizedError {
  case inaccessible(URL, underlying: Error)
  case malformed(URL)
  case unsupportedEncryption(URL)
  case printUnavailable(String)

  var errorDescription: String? {
    switch self {
    case .inaccessible(let url, _):
      "“\(url.lastPathComponent)” could not be accessed."
    case .malformed(let url):
      "“\(url.lastPathComponent)” is not a valid PDF or is corrupted."
    case .unsupportedEncryption(let url):
      "“\(url.lastPathComponent)” uses PDF encryption that this version of macOS cannot open."
    case .printUnavailable:
      "This document cannot be printed."
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
    case .printUnavailable(let reason):
      reason
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
    case .printUnavailable:
      nil
    }
  }
}
