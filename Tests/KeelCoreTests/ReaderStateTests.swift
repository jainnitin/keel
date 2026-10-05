import Foundation
import XCTest

@testable import KeelCore

@MainActor
final class ReaderStateTests: XCTestCase {
  func testStateNormalizationClampsPageAndScale() {
    let state = ReaderState(pageIndex: 99, scaleFactor: 100)
      .normalized(pageCount: 12)

    XCTAssertEqual(state.pageIndex, 11)
    XCTAssertEqual(state.scaleFactor, 16)
  }

  func testStateWithoutAutoScalesDecodesAsAutoScaling() throws {
    let json = """
      {"pageIndex": 3, "scaleFactor": 2, "layout": "continuous",
       "sidebarSection": "outline", "sidebarVisible": false}
      """
    let state = try JSONDecoder().decode(ReaderState.self, from: Data(json.utf8))

    XCTAssertEqual(state.pageIndex, 3)
    XCTAssertTrue(state.autoScales)
    XCTAssertEqual(state.sidebarSection, .outline)
  }

  func testStateWithoutCoverOptionDecodesWithCoverNotSeparate() throws {
    let json = """
      {"pageIndex": 3, "scaleFactor": 2, "layout": "singlePage",
       "sidebarSection": "outline", "sidebarVisible": false}
      """
    let state = try JSONDecoder().decode(ReaderState.self, from: Data(json.utf8))

    XCTAssertFalse(state.showsCoverSeparately)
    XCTAssertEqual(state.layout, .singlePage)
  }

  func testTwoPageLayoutAndCoverOptionRoundTrip() throws {
    let original = ReaderState(
      pageIndex: 4, layout: .twoPagesContinuous, showsCoverSeparately: true)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ReaderState.self, from: data)

    XCTAssertEqual(decoded, original)
  }

  func testUnknownLayoutKeepsTheRestOfTheSavedState() throws {
    let json = """
      {"pageIndex": 7, "scaleFactor": 1.5, "layout": "someFutureLayout",
       "sidebarSection": "outline", "sidebarVisible": false}
      """
    let state = try JSONDecoder().decode(ReaderState.self, from: Data(json.utf8))

    XCTAssertEqual(state.pageIndex, 7)
    XCTAssertEqual(state.layout, .continuous)
    XCTAssertEqual(state.sidebarSection, .outline)
  }

  func testStateStoreEvictsLeastRecentlyUsedDocument() throws {
    let suiteName = "ReaderStateTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }
    let store = ReaderStateStore(defaults: defaults, key: "states", capacity: 2)
    let first = DocumentIdentity(rawValue: "first")
    let second = DocumentIdentity(rawValue: "second")
    let third = DocumentIdentity(rawValue: "third")

    try store.save(
      ReaderState(pageIndex: 1),
      for: first,
      now: Date(timeIntervalSince1970: 1)
    )
    try store.save(
      ReaderState(pageIndex: 2),
      for: second,
      now: Date(timeIntervalSince1970: 2)
    )
    try store.save(
      ReaderState(pageIndex: 3),
      for: third,
      now: Date(timeIntervalSince1970: 3)
    )

    XCTAssertNil(try store.state(for: first))
    XCTAssertEqual(try store.state(for: second)?.pageIndex, 2)
    XCTAssertEqual(try store.state(for: third)?.pageIndex, 3)
  }

  func testStateStoreReportsCorruptPersistence() throws {
    let suiteName = "ReaderStateTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }
    defaults.set(Data("not-json".utf8), forKey: "states")
    let store = ReaderStateStore(defaults: defaults, key: "states")

    XCTAssertThrowsError(
      try store.state(for: DocumentIdentity(rawValue: "document"))
    )
    XCTAssertNil(defaults.data(forKey: "states"))

    try store.save(
      ReaderState(pageIndex: 4),
      for: DocumentIdentity(rawValue: "document")
    )
    XCTAssertEqual(
      try store.state(for: DocumentIdentity(rawValue: "document"))?.pageIndex,
      4
    )
  }
}
