import Foundation
import XCTest

@testable import KeelCore

final class PageLinkTests: XCTestCase {
  func testParsesValidLink() throws {
    let link = try XCTUnwrap(PageLink(url: url("keel://open?file=/Users/example/Book.pdf&page=7")))

    XCTAssertEqual(link.fileURL.path, "/Users/example/Book.pdf")
    XCTAssertTrue(link.fileURL.isFileURL)
    XCTAssertEqual(link.pageNumber, 7)
  }

  func testMissingPageOpensWithoutPage() throws {
    let link = try XCTUnwrap(PageLink(url: url("keel://open?file=/tmp/a.pdf")))

    XCTAssertEqual(link.fileURL.path, "/tmp/a.pdf")
    XCTAssertNil(link.pageNumber)
  }

  func testInvalidPageIsIgnored() throws {
    for page in ["abc", "0", "-3", "", "2.5"] {
      let link = try XCTUnwrap(PageLink(url: url("keel://open?file=/tmp/a.pdf&page=\(page)")))
      XCTAssertNil(link.pageNumber, "page=\(page)")
    }
  }

  func testDecodesSpacesAndUnicode() throws {
    let link = try XCTUnwrap(
      PageLink(url: url("keel://open?file=/Users/example/My%20Files/R%C3%A9sum%C3%A9%20%F0%9F%93%84.pdf&page=2"))
    )

    XCTAssertEqual(link.fileURL.path, "/Users/example/My Files/Résumé 📄.pdf")
    XCTAssertEqual(link.pageNumber, 2)
  }

  func testRejectsWrongSchemeOrHost() {
    XCTAssertNil(PageLink(url: url("https://open?file=/tmp/a.pdf&page=1")))
    XCTAssertNil(PageLink(url: url("keel://show?file=/tmp/a.pdf&page=1")))
    XCTAssertNil(PageLink(url: url("file:///tmp/a.pdf")))
  }

  func testRejectsMissingOrRelativeFile() {
    XCTAssertNil(PageLink(url: url("keel://open?page=3")))
    XCTAssertNil(PageLink(url: url("keel://open?file=&page=3")))
    XCTAssertNil(PageLink(url: url("keel://open?file=a.pdf&page=3")))
    XCTAssertNil(PageLink(url: url("keel://open")))
  }

  func testRoundTripsThroughURL() throws {
    let original = PageLink(
      fileURL: URL(filePath: "/Users/example/Q&A = notes + #1/Ünïcödé 文件.pdf"),
      pageNumber: 12
    )

    let built = original.url
    XCTAssertEqual(built.scheme, "keel")
    let parsed = try XCTUnwrap(PageLink(url: built))
    XCTAssertEqual(parsed.fileURL.path, original.fileURL.path)
    XCTAssertEqual(parsed.pageNumber, 12)
  }

  func testBuildsReadableURL() {
    let link = PageLink(fileURL: URL(filePath: "/tmp/My Book.pdf"), pageNumber: 3)

    XCTAssertEqual(link.url.absoluteString, "keel://open?file=/tmp/My%20Book.pdf&page=3")
    XCTAssertEqual(
      PageLink(fileURL: URL(filePath: "/tmp/a.pdf"), pageNumber: nil).url.absoluteString,
      "keel://open?file=/tmp/a.pdf"
    )
  }

  private func url(_ string: String) -> URL {
    URL(string: string)!
  }
}
