import AppKit
import CoreImage
import KeelCore
import PDFKit

@MainActor
final class PDFViewController: NSObject, ObservableObject {
  @Published private(set) var currentPageIndex = 0
  @Published private(set) var scaleFactor = 1.0
  @Published private(set) var autoScales = true
  @Published private(set) var canGoBack = false
  @Published private(set) var canGoForward = false

  var onStateChange: (() -> Void)?

  private weak var pdfView: PDFView?
  private weak var document: PDFDocument?
  private var pageObserver: NSObjectProtocol?
  private var scaleObserver: NSObjectProtocol?
  private var historyObserver: NSObjectProtocol?
  private var mouseButtonMonitor: Any?
  private var currentLayout: ReaderLayout?
  private var isDark: Bool?
  private var restoredState: ReaderState?

  func attach(
    _ view: PDFView,
    document: PDFDocument,
    layout: ReaderLayout,
    showsCoverSeparately: Bool,
    darkPages: Bool
  ) {
    guard pdfView !== view else {
      apply(layout: layout)
      apply(showsCoverSeparately: showsCoverSeparately)
      apply(darkPages: darkPages)
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
    apply(showsCoverSeparately: showsCoverSeparately)
    apply(darkPages: darkPages)
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
    if let historyObserver {
      NotificationCenter.default.removeObserver(historyObserver)
    }
    if let mouseButtonMonitor {
      NSEvent.removeMonitor(mouseButtonMonitor)
    }
    pageObserver = nil
    scaleObserver = nil
    historyObserver = nil
    mouseButtonMonitor = nil
    pdfView?.document = nil
    pdfView = nil
    document = nil
    currentLayout = nil
    isDark = nil
    updateHistoryState()
  }

  func restore(_ state: ReaderState) {
    guard let pdfView, let document else {
      restoredState = state
      return
    }
    apply(layout: state.layout)
    apply(showsCoverSeparately: state.showsCoverSeparately)
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
    case .twoPages:
      pdfView.displayMode = .twoUp
      pdfView.displayDirection = .horizontal
    case .twoPagesContinuous:
      pdfView.displayMode = .twoUpContinuous
      pdfView.displayDirection = .vertical
    }
  }

  func apply(showsCoverSeparately: Bool) {
    pdfView?.displaysAsBook = showsCoverSeparately
  }

  /// Renders pages light-on-dark by inverting the view's rendering and rotating hue back, so
  /// text and white paper flip while photos keep roughly natural colors. The document is
  /// untouched, and selection, links, and scrolling are unaffected because only the layer's
  /// output is filtered.
  func apply(darkPages: Bool) {
    guard isDark != darkPages, let pdfView else {
      return
    }
    isDark = darkPages
    if darkPages {
      pdfView.wantsLayer = true
      pdfView.layerUsesCoreImageFilters = true
      let hue = CIFilter(name: "CIHueAdjust", parameters: [kCIInputAngleKey: Double.pi])
      pdfView.layer?.filters = [CIFilter(name: "CIColorInvert"), hue].compactMap { $0 }
      // The filter inverts this too, so it ends up as a dark gray surround.
      pdfView.backgroundColor = NSColor(white: 0.85, alpha: 1)
    } else {
      pdfView.layer?.filters = nil
      pdfView.backgroundColor = .windowBackgroundColor
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

  /// Returns to the location before the last jump (a link, contents entry, or search result).
  func goBack() {
    pdfView?.goBack(nil)
  }

  func goForward() {
    pdfView?.goForward(nil)
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
    let margins = pdfView.pageBreakMargins
    let availableWidth = max(pdfView.bounds.width - margins.left - margins.right, 1)
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
    // Go back and forward with mouse side buttons and swipes, as in a web browser. PDFView's
    // inner views receive these events first, so watch the window's events instead.
    mouseButtonMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.otherMouseDown, .otherMouseUp, .swipe]
    ) { [weak self] event in
      let handled = MainActor.assumeIsolated {
        self?.handleNavigationEvent(event) ?? false
      }
      return handled ? nil : event
    }
    historyObserver = NotificationCenter.default.addObserver(
      forName: .PDFViewChangedHistory,
      object: view,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.updateHistoryState()
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

  /// Handles back/forward from mouse side buttons (buttons 4 and 5) and swipes; many mice
  /// send their back and forward buttons as swipes. Returns whether the event was handled.
  private func handleNavigationEvent(_ event: NSEvent) -> Bool {
    guard let pdfView, event.window === pdfView.window else {
      return false
    }
    switch event.type {
    case .swipe where event.deltaX > 0:
      goBack()
    case .swipe where event.deltaX < 0:
      goForward()
    case .otherMouseUp where event.buttonNumber == 3:
      goBack()
    case .otherMouseUp where event.buttonNumber == 4:
      goForward()
    case .otherMouseDown:
      // Swallow the press of a button whose release navigates.
      return event.buttonNumber == 3 || event.buttonNumber == 4
    default:
      return false
    }
    return true
  }

  private func updateHistoryState() {
    canGoBack = pdfView?.canGoBack ?? false
    canGoForward = pdfView?.canGoForward ?? false
  }
}
