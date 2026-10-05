import Foundation

public protocol PasswordStore: Sendable {
  func password(for identity: DocumentIdentity) async throws -> String?
  func setPassword(_ password: String, for identity: DocumentIdentity) async throws
  func removePassword(for identity: DocumentIdentity) async throws
}
