import KeelCore
import PDFKit

/// Decides once per document whether it has any searchable text, so the UI can explain
/// that a scanned (image-only) PDF can't be searched instead of showing "No Results".
///
/// The check reads `PDFPage.string` for a bounded sample of pages (see `TextLayerSampling`)
/// and stops at the first page with text. PDFKit objects aren't `Sendable`, so this stays on
/// the main actor and yields between pages to keep the UI responsive; text documents
/// normally finish on page 1, and image-only pages return an empty string almost instantly.
@MainActor
enum TextLayerDetector {
  /// Returns `nil` when the document is locked (its text isn't readable yet) or the task
  /// was cancelled, so callers can retry later rather than caching a wrong answer.
  static func hasSearchableText(in document: PDFDocument) async -> Bool? {
    guard !document.isLocked else {
      return nil
    }
    for index in TextLayerSampling.pageIndices(pageCount: document.pageCount) {
      if Task.isCancelled {
        return nil
      }
      if TextLayerSampling.containsText(document.page(at: index)?.string) {
        return true
      }
      await Task.yield()
    }
    return false
  }
}
