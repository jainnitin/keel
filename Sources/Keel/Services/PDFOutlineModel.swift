import Foundation
import PDFKit

struct PDFOutlineNode: Identifiable {
  let id: String
  let title: String
  let pageIndex: Int?
  let children: [PDFOutlineNode]
}

@MainActor
enum PDFOutlineBuilder {
  static func build(document: PDFDocument) -> [PDFOutlineNode] {
    guard let root = document.outlineRoot else {
      return []
    }
    return children(of: root, document: document, path: "root")
  }

  private static func children(
    of outline: PDFOutline,
    document: PDFDocument,
    path: String
  ) -> [PDFOutlineNode] {
    (0..<outline.numberOfChildren).compactMap { index in
      guard let child = outline.child(at: index) else {
        return nil
      }
      let childPath = "\(path).\(index)"
      let destinationPage =
        child.destination?.page
        ?? child.action.flatMap {
          ($0 as? PDFActionGoTo)?.destination.page
        }
      let pageIndex = destinationPage.map(document.index(for:)).flatMap {
        $0 == NSNotFound ? nil : $0
      }
      return PDFOutlineNode(
        id: childPath,
        title: child.label?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
          ?? "Untitled Section",
        pageIndex: pageIndex,
        children: children(of: child, document: document, path: childPath)
      )
    }
  }
}

extension String {
  fileprivate var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
