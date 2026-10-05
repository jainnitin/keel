import Foundation

/// Decides which pages to inspect when checking whether a PDF has a text layer, and
/// whether a page's extracted text counts as real text.
///
/// Heuristic: a document is searchable if any inspected page has non-whitespace text.
/// Small documents are inspected in full. Larger ones are sampled: the first
/// `leadingCount` pages plus `spreadCount` pages spread evenly over the rest (including the
/// last page), so a scanned cover or blank front matter doesn't hide a text body, and a
/// bounded number of pages is read no matter how large the document is.
public enum TextLayerSampling {
  public static let defaultLeadingCount = 20
  public static let defaultSpreadCount = 6

  /// Zero-based page indices to inspect, ascending and without duplicates.
  public static func pageIndices(
    pageCount: Int,
    leadingCount: Int = defaultLeadingCount,
    spreadCount: Int = defaultSpreadCount
  ) -> [Int] {
    guard pageCount > 0 else {
      return []
    }
    let leading = min(max(leadingCount, 0), pageCount)
    var indices = Array(0..<leading)
    let remaining = pageCount - leading
    let spread = min(max(spreadCount, 0), remaining)
    if spread > 0 {
      // Evenly spaced over leading..<pageCount, ending on the last page.
      for step in 1...spread {
        indices.append(leading + (remaining * step) / spread - 1)
      }
    }
    return indices
  }

  /// Whether extracted page text contains anything other than whitespace.
  public static func containsText(_ pageText: String?) -> Bool {
    guard let pageText else {
      return false
    }
    return pageText.contains { !$0.isWhitespace && !$0.isNewline }
  }
}
