import AppKit
import KeelCore
import PDFKit

@MainActor
final class PDFViewController: NSObject, ObservableObject {
  @Published private(set) var currentPageIndex = 0
  @Published private(set) var scaleFactor = 1.0
  @Published private(set) var autoScales = true

  var onStateChange: (() -> Void)?

  private weak var pdfView: PDFView?
  private weak var document: PDFDocument?
  private var pageObserver: NSObjectProtocol?
  private var scaleObserver: NSObjectProtocol?
  private var currentLayout: ReaderLayout?
  private var restoredState: ReaderState?

  func attach(_ view: PDFView, document: PDFDocument, layout: ReaderLayout) {
    guard pdfView !== view else {
      apply(layout: layout)
      return
    }

    detach()
    pdfView = view
    self.document = document
    view.document = document
    view.backgroundColor = .windowBackgroundColor
    view.displaysPageBreaks = true
    view.pageBreakMargins = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    view.minScaleFactor = 0.1
    view.maxScaleFactor = 16
    view.autoScales = true
    view.setAccessibilityLabel("PDF document")
    apply(layout: layout)
    installObservers(for: view)

    if let restoredState {
      restore(restoredState)
      self.restoredState = nil
    } else {
      updatePublishedState()
    }
  }

  func detach() {
    if let pageObserver {
      NotificationCenter.default.removeObserver(pageObserver)
    }
    if let scaleObserver {
      NotificationCenter.default.removeObserver(scaleObserver)
    }
    pageObserver = nil
    scaleObserver = nil
    pdfView?.document = nil
    pdfView = nil
    document = nil
    currentLayout = nil
  }

  func restore(_ state: ReaderState) {
    guard let pdfView, let document else {
      restoredState = state
      return
    }
    apply(layout: state.layout)
    if let page = document.page(at: state.pageIndex) {
      pdfView.go(to: page)
    }
    if state.autoScales {
      pdfView.autoScales = true
    } else {
      pdfView.autoScales = false
      pdfView.scaleFactor = min(
        max(state.scaleFactor, pdfView.minScaleFactor), pdfView.maxScaleFactor)
    }
    updatePublishedState()
  }

  func apply(layout: ReaderLayout) {
    guard currentLayout != layout, let pdfView else {
      return
    }
    currentLayout = layout
    switch layout {
    case .continuous:
      pdfView.displayMode = .singlePageContinuous
      pdfView.displayDirection = .vertical
    case .singlePage:
      pdfView.displayMode = .singlePage
      pdfView.displayDirection = .horizontal
    }
  }

  func previousPage() {
    pdfView?.goToPreviousPage(nil)
  }

  func nextPage() {
    pdfView?.goToNextPage(nil)
  }

  func go(toPageIndex index: Int) {
    guard let page = document?.page(at: index) else {
      return
    }
    pdfView?.go(to: page)
  }

  func go(to selection: PDFSelection) {
    pdfView?.setCurrentSelection(selection, animate: true)
    pdfView?.go(to: selection)
  }

  func zoomIn() {
    guard let pdfView else {
      return
    }
    pdfView.autoScales = false
    pdfView.zoomIn(nil)
  }

  func zoomOut() {
    guard let pdfView else {
      return
    }
    pdfView.autoScales = false
    pdfView.zoomOut(nil)
  }

  /// Fits the page to the window and keeps fitting as the window resizes.
  func zoomToFit() {
    pdfView?.autoScales = true
    updatePublishedState()
  }

  func actualSize() {
    guard let pdfView else {
      return
    }
    pdfView.autoScales = false
    pdfView.scaleFactor = 1
    // No scale notification arrives when the scale was already 1, but auto-fit still changed.
    updatePublishedState()
  }

  func fitToWidth() {
    guard
      let pdfView,
      let page = pdfView.currentPage
    else {
      return
    }
    let pageBounds = page.bounds(for: pdfView.displayBox)
    guard pageBounds.width > 0 else {
      return
    }
    let availableWidth = max(pdfView.bounds.width - 32, 1)
    pdfView.autoScales = false
    pdfView.scaleFactor = min(
      max(availableWidth / pageBounds.width, pdfView.minScaleFactor),
      pdfView.maxScaleFactor
    )
    updatePublishedState()
  }

  private func installObservers(for view: PDFView) {
    pageObserver = NotificationCenter.default.addObserver(
      forName: .PDFViewPageChanged,
      object: view,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.updatePublishedState()
      }
    }
    scaleObserver = NotificationCenter.default.addObserver(
      forName: .PDFViewScaleChanged,
      object: view,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.updatePublishedState()
      }
    }
  }

  private func updatePublishedState() {
    guard let pdfView, let document else {
      return
    }
    if let page = pdfView.currentPage {
      let index = document.index(for: page)
      if index != NSNotFound {
        currentPageIndex = index
      }
    }
    scaleFactor = pdfView.scaleFactor
    autoScales = pdfView.autoScales
    onStateChange?()
  }
}
