import Foundation

/// A `keel://open?file=<absolute path>&page=<1-based page>` link to a page of a local PDF.
public struct PageLink: Equatable, Sendable {
  public static let scheme = "keel"

  public let fileURL: URL
  /// The 1-based page number, or `nil` to open at the restored reading position.
  public let pageNumber: Int?

  public init(fileURL: URL, pageNumber: Int?) {
    self.fileURL = fileURL
    self.pageNumber = pageNumber.flatMap { $0 > 0 ? $0 : nil }
  }

  public init?(url: URL) {
    guard
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme?.lowercased() == Self.scheme,
      components.host?.lowercased() == "open",
      let items = components.queryItems,
      let path = items.first(where: { $0.name == "file" })?.value,
      path.hasPrefix("/")
    else {
      return nil
    }
    let page = items.first(where: { $0.name == "page" })?.value.flatMap { Int($0) }
    self.init(fileURL: URL(filePath: path), pageNumber: page)
  }

  public var url: URL {
    var components = URLComponents()
    components.scheme = Self.scheme
    components.host = "open"
    var query = "file=" + Self.encode(fileURL.path)
    if let pageNumber {
      query += "&page=\(pageNumber)"
    }
    components.percentEncodedQuery = query
    // The components are all valid, so this can't fail.
    return components.url!
  }

  /// Encodes everything except unreserved characters and `/`, so `&`, `=`, `+`, and `#` survive.
  private static func encode(_ value: String) -> String {
    var allowed = CharacterSet(charactersIn: "-._~/")
    allowed.formUnion(CharacterSet(charactersIn: "a"..."z"))
    allowed.formUnion(CharacterSet(charactersIn: "A"..."Z"))
    allowed.formUnion(CharacterSet(charactersIn: "0"..."9"))
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }
}
