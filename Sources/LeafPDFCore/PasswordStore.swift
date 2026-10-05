import Foundation

public protocol PasswordStore: Sendable {
  func password(for identity: DocumentIdentity) async throws -> String?
  func setPassword(_ password: String, for identity: DocumentIdentity) async throws
  func removePassword(for identity: DocumentIdentity) async throws
}

public actor PasswordCoordinator {
  private let store: any PasswordStore

  public init(store: any PasswordStore) {
    self.store = store
  }

  public func storedPassword(for identity: DocumentIdentity) async throws -> String? {
    try await store.password(for: identity)
  }

  public func remember(_ password: String, for identity: DocumentIdentity) async throws {
    try await store.setPassword(password, for: identity)
  }

  public func forget(_ identity: DocumentIdentity) async throws {
    try await store.removePassword(for: identity)
  }
}
