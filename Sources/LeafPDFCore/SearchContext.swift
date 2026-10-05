import Foundation

public enum SearchContext {
  public static func excerpt(
    in source: String,
    matching query: String,
    maximumLength: Int = 140
  ) -> String {
    let normalized = source.replacingOccurrences(
      of: #"\s+"#,
      with: " ",
      options: .regularExpression
    )
    guard !normalized.isEmpty else {
      return ""
    }

    let limit = max(maximumLength, query.count)
    guard normalized.count > limit else {
      return normalized
    }

    let match = normalized.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
    let center =
      match.map { normalized.distance(from: normalized.startIndex, to: $0.lowerBound) }
      ?? 0
    let leadingCount = min(max((limit - query.count) / 2, 0), center)
    let startOffset = max(center - leadingCount, 0)
    let start = normalized.index(normalized.startIndex, offsetBy: startOffset)
    let end = normalized.index(
      start, offsetBy: min(limit, normalized.distance(from: start, to: normalized.endIndex)))
    var result = String(normalized[start..<end])

    if start != normalized.startIndex {
      result = "…" + result
    }
    if end != normalized.endIndex {
      result += "…"
    }
    return result
  }
}
