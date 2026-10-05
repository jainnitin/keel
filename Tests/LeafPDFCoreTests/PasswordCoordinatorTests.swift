import XCTest

@testable import LeafPDFCore

final class PasswordCoordinatorTests: XCTestCase {
  func testRememberReadAndForgetPassword() async throws {
    let store = TestPasswordStore()
    let coordinator = PasswordCoordinator(store: store)
    let identity = DocumentIdentity(rawValue: "document")

    XCTAssertNil(try await coordinator.storedPassword(for: identity))
    try await coordinator.remember("correct horse battery staple", for: identity)
    XCTAssertEqual(
      try await coordinator.storedPassword(for: identity),
      "correct horse battery staple"
    )
    try await coordinator.forget(identity)
    XCTAssertNil(try await coordinator.storedPassword(for: identity))
  }

  func testStoreErrorsArePropagated() async {
    let coordinator = PasswordCoordinator(store: FailingPasswordStore())

    await assertThrowsErrorAsync(
      try await coordinator.storedPassword(for: DocumentIdentity(rawValue: "document"))
    )
  }
}

private actor TestPasswordStore: PasswordStore {
  private var passwords: [DocumentIdentity: String] = [:]

  func password(for identity: DocumentIdentity) -> String? {
    passwords[identity]
  }

  func setPassword(_ password: String, for identity: DocumentIdentity) {
    passwords[identity] = password
  }

  func removePassword(for identity: DocumentIdentity) {
    passwords.removeValue(forKey: identity)
  }
}

private struct FailingPasswordStore: PasswordStore {
  func password(for identity: DocumentIdentity) async throws -> String? {
    throw TestPasswordStoreError.expected
  }

  func setPassword(_ password: String, for identity: DocumentIdentity) async throws {
    throw TestPasswordStoreError.expected
  }

  func removePassword(for identity: DocumentIdentity) async throws {
    throw TestPasswordStoreError.expected
  }
}

private enum TestPasswordStoreError: Error {
  case expected
}

private func assertThrowsErrorAsync<T>(
  _ expression: @autoclosure () async throws -> T,
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  do {
    _ = try await expression()
    XCTFail("Expected an error to be thrown.", file: file, line: line)
  } catch {
    XCTAssertTrue(error is TestPasswordStoreError, file: file, line: line)
  }
}
