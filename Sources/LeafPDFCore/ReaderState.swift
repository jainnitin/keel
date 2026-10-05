import Foundation

public enum ReaderLayout: String, Codable, CaseIterable, Sendable {
  case continuous
  case singlePage
}

public enum ReaderSidebarSection: String, Codable, CaseIterable, Sendable {
  case thumbnails
  case outline
  case search
}

public struct ReaderState: Codable, Equatable, Sendable {
  public var pageIndex: Int
  public var scaleFactor: Double
  public var layout: ReaderLayout
  public var sidebarSection: ReaderSidebarSection
  public var sidebarVisible: Bool

  public init(
    pageIndex: Int = 0,
    scaleFactor: Double = 1,
    layout: ReaderLayout = .continuous,
    sidebarSection: ReaderSidebarSection = .thumbnails,
    sidebarVisible: Bool = true
  ) {
    self.pageIndex = pageIndex
    self.scaleFactor = scaleFactor
    self.layout = layout
    self.sidebarSection = sidebarSection
    self.sidebarVisible = sidebarVisible
  }

  public func normalized(pageCount: Int) -> ReaderState {
    var copy = self
    copy.pageIndex = min(max(pageIndex, 0), max(pageCount - 1, 0))
    copy.scaleFactor = min(max(scaleFactor, 0.1), 16)
    return copy
  }
}

public struct PersistedReaderState: Codable, Equatable, Sendable {
  public var state: ReaderState
  public var lastUsed: Date

  public init(state: ReaderState, lastUsed: Date) {
    self.state = state
    self.lastUsed = lastUsed
  }
}

@MainActor
public final class ReaderStateStore {
  public static let shared = ReaderStateStore()

  private let defaults: UserDefaults
  private let key: String
  private let capacity: Int

  public init(
    defaults: UserDefaults = .standard,
    key: String = "readerStates.v1",
    capacity: Int = 50
  ) {
    self.defaults = defaults
    self.key = key
    self.capacity = max(capacity, 1)
  }

  public func state(for identity: DocumentIdentity) throws -> ReaderState? {
    try load()[identity.rawValue]?.state
  }

  public func save(
    _ state: ReaderState,
    for identity: DocumentIdentity,
    now: Date = Date()
  ) throws {
    var states = try load()
    states[identity.rawValue] = PersistedReaderState(state: state, lastUsed: now)

    if states.count > capacity {
      let retained =
        states
        .sorted { $0.value.lastUsed > $1.value.lastUsed }
        .prefix(capacity)
        .map { ($0.key, $0.value) }
      states = Dictionary(uniqueKeysWithValues: retained)
    }

    let data = try JSONEncoder().encode(states)
    defaults.set(data, forKey: key)
  }

  public func removeState(for identity: DocumentIdentity) throws {
    var states = try load()
    states.removeValue(forKey: identity.rawValue)
    let data = try JSONEncoder().encode(states)
    defaults.set(data, forKey: key)
  }

  private func load() throws -> [String: PersistedReaderState] {
    guard let data = defaults.data(forKey: key) else {
      return [:]
    }
    do {
      return try JSONDecoder().decode([String: PersistedReaderState].self, from: data)
    } catch {
      defaults.removeObject(forKey: key)
      throw error
    }
  }
}
