import CryptoKit
import Foundation

public struct DocumentIdentity: RawRepresentable, Codable, Hashable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(metadata: DocumentIdentityMetadata) {
    let components: [String]
    if let volumeIdentifier = metadata.volumeIdentifier,
      let fileResourceIdentifier = metadata.fileResourceIdentifier
    {
      components = ["resource", volumeIdentifier, fileResourceIdentifier]
    } else {
      components = [
        "fallback",
        metadata.standardizedPath,
        metadata.fileSize.map(String.init) ?? "",
        metadata.creationDate?.timeIntervalSince1970.description ?? "",
      ]
    }
    let digest = SHA256.hash(data: Data(components.joined(separator: "\u{1F}").utf8))
    rawValue = digest.map { String(format: "%02x", $0) }.joined()
  }

  public var shortValue: String {
    String(rawValue.prefix(12))
  }
}

public struct DocumentIdentityMetadata: Equatable, Sendable {
  public let standardizedPath: String
  public let volumeIdentifier: String?
  public let fileResourceIdentifier: String?
  public let fileSize: Int64?
  public let creationDate: Date?

  public init(
    standardizedPath: String,
    volumeIdentifier: String?,
    fileResourceIdentifier: String?,
    fileSize: Int64?,
    creationDate: Date?
  ) {
    self.standardizedPath = standardizedPath
    self.volumeIdentifier = volumeIdentifier
    self.fileResourceIdentifier = fileResourceIdentifier
    self.fileSize = fileSize
    self.creationDate = creationDate
  }
}

public enum DocumentIdentityError: LocalizedError, Equatable {
  case notARegularFile
  case unreadable

  public var errorDescription: String? {
    switch self {
    case .notARegularFile:
      "The selected item is not a regular file."
    case .unreadable:
      "The selected PDF is not readable."
    }
  }
}

extension DocumentIdentity {
  public static func resolve(url: URL) throws -> DocumentIdentity {
    let keys: Set<URLResourceKey> = [
      .isRegularFileKey,
      .isReadableKey,
      .fileResourceIdentifierKey,
      .volumeIdentifierKey,
      .fileSizeKey,
      .creationDateKey,
    ]
    let values = try url.resourceValues(forKeys: keys)
    guard values.isRegularFile == true else {
      throw DocumentIdentityError.notARegularFile
    }
    guard values.isReadable == true else {
      throw DocumentIdentityError.unreadable
    }

    return DocumentIdentity(
      metadata: DocumentIdentityMetadata(
        standardizedPath: url.standardizedFileURL.path,
        volumeIdentifier: values.volumeIdentifier.map(String.init(describing:)),
        fileResourceIdentifier: values.fileResourceIdentifier.map(String.init(describing:)),
        fileSize: values.fileSize.map(Int64.init),
        creationDate: values.creationDate
      )
    )
  }
}
