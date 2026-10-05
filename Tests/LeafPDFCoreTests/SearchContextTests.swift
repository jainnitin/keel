import XCTest

@testable import LeafPDFCore

final class SearchContextTests: XCTestCase {
  func testExcerptCentersMatchAndNormalizesWhitespace() {
    let source = """
      A long introduction with
      irregular spacing before the important needle and a long conclusion.
      """

    let excerpt = SearchContext.excerpt(
      in: source,
      matching: "needle",
      maximumLength: 45
    )

    XCTAssertTrue(excerpt.contains("needle"))
    XCTAssertFalse(excerpt.contains("\n"))
    XCTAssertLessThanOrEqual(excerpt.count, 47)
  }
}
