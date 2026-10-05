import Foundation
import XCTest

@testable import KeelCore

final class DocumentIdentityTests: XCTestCase {
  func testIdentityIsStableForSameMetadata() {
    let metadata = DocumentIdentityMetadata(
      standardizedPath: "/Users/example/Documents/sample.pdf",
      volumeIdentifier: "volume",
      fileResourceIdentifier: "file-42",
      fileSize: 1_024,
      creationDate: Date(timeIntervalSince1970: 123)
    )

    XCTAssertEqual(
      DocumentIdentity(metadata: metadata),
      DocumentIdentity(metadata: metadata)
    )
  }

  func testIdentityChangesWhenStableFileIdentifierChanges() {
    let first = DocumentIdentity(
      metadata: DocumentIdentityMetadata(
        standardizedPath: "/tmp/sample.pdf",
        volumeIdentifier: "volume",
        fileResourceIdentifier: "file-1",
        fileSize: 1_024,
        creationDate: nil
      )
    )
    let second = DocumentIdentity(
      metadata: DocumentIdentityMetadata(
        standardizedPath: "/tmp/sample.pdf",
        volumeIdentifier: "volume",
        fileResourceIdentifier: "file-2",
        fileSize: 1_024,
        creationDate: nil
      )
    )

    XCTAssertNotEqual(first, second)
  }

  func testIdentitySurvivesRenameWhenResourceIdentifierIsAvailable() {
    let original = DocumentIdentity(
      metadata: DocumentIdentityMetadata(
        standardizedPath: "/Users/example/Original.pdf",
        volumeIdentifier: "volume",
        fileResourceIdentifier: "file-42",
        fileSize: 1_024,
        creationDate: nil
      )
    )
    let renamed = DocumentIdentity(
      metadata: DocumentIdentityMetadata(
        standardizedPath: "/Users/example/Renamed.pdf",
        volumeIdentifier: "volume",
        fileResourceIdentifier: "file-42",
        fileSize: 1_024,
        creationDate: nil
      )
    )

    XCTAssertEqual(original, renamed)
  }

  func testResolvedIdentityRejectsDirectory() throws {
    XCTAssertThrowsError(try DocumentIdentity.resolve(url: FileManager.default.temporaryDirectory))
    {
      XCTAssertEqual($0 as? DocumentIdentityError, .notARegularFile)
    }
  }
}
