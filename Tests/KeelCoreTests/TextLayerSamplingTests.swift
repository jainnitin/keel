import XCTest

@testable import KeelCore

final class TextLayerSamplingTests: XCTestCase {
  func testEmptyDocumentHasNoPages() {
    XCTAssertEqual(TextLayerSampling.pageIndices(pageCount: 0), [])
    XCTAssertEqual(TextLayerSampling.pageIndices(pageCount: -3), [])
  }

  func testSmallDocumentIsInspectedInFull() {
    XCTAssertEqual(TextLayerSampling.pageIndices(pageCount: 1), [0])
    XCTAssertEqual(TextLayerSampling.pageIndices(pageCount: 20), Array(0..<20))
    XCTAssertEqual(TextLayerSampling.pageIndices(pageCount: 26), Array(0..<26))
  }

  func testLargeDocumentIsBoundedAndSpread() {
    let indices = TextLayerSampling.pageIndices(pageCount: 1_000)
    XCTAssertEqual(indices.count, 26)
    XCTAssertEqual(Array(indices.prefix(20)), Array(0..<20))
    XCTAssertEqual(indices.last, 999)
    XCTAssertEqual(Set(indices).count, indices.count)
    XCTAssertEqual(indices, indices.sorted())
    XCTAssertTrue(indices.allSatisfy { (0..<1_000).contains($0) })
  }

  func testSlightlyOverLeadingCountStaysInRange() {
    XCTAssertEqual(TextLayerSampling.pageIndices(pageCount: 23), Array(0..<23))
  }

  func testNegativeCountsAreTreatedAsZero() {
    XCTAssertEqual(
      TextLayerSampling.pageIndices(pageCount: 5, leadingCount: -1, spreadCount: -1),
      []
    )
    XCTAssertEqual(
      TextLayerSampling.pageIndices(pageCount: 5, leadingCount: 0, spreadCount: 2),
      [1, 4]
    )
  }

  func testContainsText() {
    XCTAssertFalse(TextLayerSampling.containsText(nil))
    XCTAssertFalse(TextLayerSampling.containsText(""))
    XCTAssertFalse(TextLayerSampling.containsText(" \n\t\r\n \u{00A0}"))
    XCTAssertTrue(TextLayerSampling.containsText("\n a \n"))
    XCTAssertTrue(TextLayerSampling.containsText("日本語"))
  }
}
