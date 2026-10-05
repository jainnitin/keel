import Foundation

public enum ReaderLayout: String, Codable, CaseIterable, Sendable {
  case continuous
  case singlePage
  case twoPages
  case twoPagesContinuous
}

public enum ReaderSidebarSection: String, Codable, CaseIterable, Sendable {
  case thumbnails
  case outline
  case search
}

public struct ReaderState: Codable, Equatable, Sendable {
  public var pageIndex: Int
  /// When true the view keeps fitting the page to the window and `scaleFactor` is ignored.
  public var autoScales: Bool
  public var scaleFactor: Double
  public var layout: ReaderLayout
  /// In the two-page layouts, shows the first page alone (a book cover) with spreads after it.
  public var showsCoverSeparately: Bool
  public var sidebarSection: ReaderSidebarSection
  public var sidebarVisible: Bool

  public init(
    pageIndex: Int = 0,
    autoScales: Bool = true,
    scaleFactor: Double = 1,
    layout: ReaderLayout = .continuous,
    showsCoverSeparately: Bool = false,
    sidebarSection: ReaderSidebarSection = .thumbnails,
    sidebarVisible: Bool = true
  ) {
    self.pageIndex = pageIndex
    self.autoScales = autoScales
    self.scaleFactor = scaleFactor
    self.layout = layout
    self.showsCoverSeparately = showsCoverSeparately
    self.sidebarSection = sidebarSection
    self.sidebarVisible = sidebarVisible
  }

  public init(from decoder: Decoder) throws {
    // Decode keys added after the first release leniently so saved positions survive upgrades.
    let container = try decoder.container(keyedBy: CodingKeys.self)
    pageIndex = try container.decode(Int.self, forKey: .pageIndex)
    autoScales = try container.decodeIfPresent(Bool.self, forKey: .autoScales) ?? true
    scaleFactor = try container.decode(Double.self, forKey: .scaleFactor)
    // A layout written by a newer version falls back to the default instead of dropping the state.
    layout = (try? container.decodeIfPresent(ReaderLayout.self, forKey: .layout)) ?? .continuous
    showsCoverSeparately =
      try container.decodeIfPresent(Bool.self, forKey: .showsCoverSeparately) ?? false
    sidebarSection = try container.decode(ReaderSidebarSection.self, forKey: .sidebarSection)
    sidebarVisible = try container.decode(Bool.self, forKey: .sidebarVisible)
  }

  public func normalized(pageCount: Int) -> ReaderState {
    var copy = self
    copy.pageIndex = min(max(pageIndex, 0), max(pageCount - 1, 0))
    copy.scaleFactor = min(max(scaleFactor, 0.1), 16)
    return copy
  }
}

struct PersistedReaderState: Codable, Equatable, Sendable {
  var state: ReaderState
  var lastUsed: Date
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
