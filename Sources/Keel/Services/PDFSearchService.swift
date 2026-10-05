import Foundation
import KeelCore
import PDFKit

struct PDFSearchResult: Identifiable, Equatable {
  let id: Int
  let pageIndex: Int
  let pageLabel: String
  let excerpt: String
}

private struct PDFSearchMatch: @unchecked Sendable {
  let selection: PDFSelection
}

@MainActor
final class PDFSearchService: NSObject, ObservableObject, PDFDocumentDelegate {
  @Published private(set) var results: [PDFSearchResult] = []
  @Published private(set) var isSearching = false

  private weak var document: PDFDocument?
  private var selections: [Int: PDFSelection] = [:]
  private var query = ""
  private var nextResultID = 0

  init(document: PDFDocument) {
    self.document = document
    super.init()
    document.delegate = self
  }

  func search(_ query: String) {
    guard let document else {
      return
    }

    document.cancelFindString()
    results.removeAll(keepingCapacity: true)
    selections.removeAll(keepingCapacity: true)
    nextResultID = 0
    self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !self.query.isEmpty else {
      isSearching = false
      return
    }

    isSearching = true
    document.beginFindString(
      self.query,
      withOptions: [.caseInsensitive, .diacriticInsensitive]
    )
  }

  func selection(for result: PDFSearchResult) -> PDFSelection? {
    selections[result.id]
  }

  func tearDown() {
    document?.cancelFindString()
    isSearching = false
    if document?.delegate === self {
      document?.delegate = nil
    }
    document = nil
    results.removeAll()
    selections.removeAll()
  }

  nonisolated func documentDidBeginDocumentFind(_ notification: Notification) {
    Task { @MainActor [weak self] in
      self?.isSearching = true
    }
  }

  nonisolated func documentDidEndDocumentFind(_ notification: Notification) {
    Task { @MainActor [weak self] in
      self?.isSearching = false
    }
  }

  nonisolated func documentDidFindMatch(_ notification: Notification) {
    guard let selection = notification.userInfo?.values.compactMap({ $0 as? PDFSelection }).first
    else {
      return
    }
    let match = PDFSearchMatch(selection: selection)
    Task { @MainActor [weak self, match] in
      self?.append(match.selection)
    }
  }

  private func append(_ selection: PDFSelection) {
    guard
      let document,
      let page = selection.pages.first,
      case let pageIndex = document.index(for: page),
      pageIndex != NSNotFound,
      selection.string?.compare(
        query,
        options: [.caseInsensitive, .diacriticInsensitive]
      ) == .orderedSame
    else {
      return
    }

    let id = nextResultID
    nextResultID += 1
    let contextualSelection = (selection.copy() as? PDFSelection) ?? selection
    contextualSelection.extend(atStart: 70)
    contextualSelection.extend(atEnd: 70)
    let source = contextualSelection.string ?? selection.string ?? ""
    let result = PDFSearchResult(
      id: id,
      pageIndex: pageIndex,
      pageLabel: page.label ?? String(pageIndex + 1),
      excerpt: SearchContext.excerpt(in: source, matching: query)
    )
    selections[id] = selection
    results.append(result)
  }
}
