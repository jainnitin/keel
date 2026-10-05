import AppKit
import Foundation
import KeelCore
import PDFKit

@MainActor
final class ReaderViewModel: ObservableObject {
  enum AccessState: Equatable {
    case preparing
    case locked
    case ready
    case failed
  }

  struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
  }

  @Published private(set) var accessState: AccessState = .preparing
  @Published var layout: ReaderLayout = .continuous {
    didSet {
      viewer.apply(layout: layout)
      scheduleStateSave()
    }
  }
  @Published var sidebarSection: ReaderSidebarSection = .thumbnails {
    didSet {
      if sidebarSection != .search {
        browsingSection = sidebarSection
      }
      scheduleStateSave()
    }
  }
  @Published var sidebarVisible = true {
    didSet {
      scheduleStateSave()
    }
  }
  @Published var searchQuery = ""
  @Published var isPasswordPromptPresented = false
  @Published var passwordError: String?
  @Published private(set) var hasSavedPassword = false
  @Published var presentedError: PresentedError?
  @Published private(set) var failureMessage = "The document contains no readable pages."

  let identity: DocumentIdentity
  let sourceURL: URL
  let document: PDFDocument
  let viewer = PDFViewController()
  let searchService: PDFSearchService
  let thumbnailService: ThumbnailService

  private(set) var outline: [PDFOutlineNode] = []
  /// The non-search section to return to when the search query is cleared.
  private var browsingSection: ReaderSidebarSection = .thumbnails
  private let passwordStore: any PasswordStore
  private let stateStore: ReaderStateStore
  private var accessTask: Task<Void, Never>?
  private var unlockTask: Task<Void, Never>?
  private var passwordTask: Task<Void, Never>?
  private var searchTask: Task<Void, Never>?
  private var stateSaveTask: Task<Void, Never>?
  private var isTornDown = false
  private var didPresentStatePersistenceError = false

  init(
    document: PDFDocument,
    identity: DocumentIdentity,
    sourceURL: URL,
    passwordStore: any PasswordStore = KeychainPasswordStore.shared,
    stateStore: ReaderStateStore = .shared
  ) {
    self.document = document
    self.identity = identity
    self.sourceURL = sourceURL
    self.passwordStore = passwordStore
    self.stateStore = stateStore
    searchService = PDFSearchService(document: document)
    thumbnailService = ThumbnailService(url: sourceURL)
    viewer.onStateChange = { [weak self] in
      self?.scheduleStateSave()
    }
  }

  var pageCount: Int {
    document.pageCount
  }

  var hasSearchQuery: Bool {
    !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func prepare() {
    guard accessState == .preparing else {
      return
    }
    accessTask = Task { [weak self] in
      await self?.prepareAccess()
    }
  }

  func updateSearchQuery() {
    searchTask?.cancel()
    let query = searchQuery
    if hasSearchQuery {
      sidebarSection = .search
      sidebarVisible = true
    } else if sidebarSection == .search {
      sidebarSection = browsingSection
    }
    searchTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else {
        return
      }
      self?.searchService.search(query)
    }
  }

  func unlock(password: String, remember: Bool) {
    passwordError = nil
    guard !password.isEmpty else {
      passwordError = "Enter the PDF password."
      return
    }
    guard document.unlock(withPassword: password) else {
      passwordError = "The password is incorrect, or the PDF uses unsupported encryption."
      return
    }

    isPasswordPromptPresented = false
    unlockTask?.cancel()
    unlockTask = Task { [weak self] in
      guard let self else {
        return
      }
      defer {
        unlockTask = nil
      }
      await prepareThumbnails(password: password)
      guard !Task.isCancelled, !isTornDown else {
        return
      }
      finishUnlock()

      if remember {
        do {
          try await passwordStore.setPassword(password, for: identity)
          guard !Task.isCancelled, !isTornDown else {
            return
          }
          hasSavedPassword = true
        } catch {
          guard !Task.isCancelled, !isTornDown else {
            return
          }
          present(error, title: "Password Was Not Saved")
        }
      }
    }
  }

  func forgetSavedPassword() {
    passwordTask?.cancel()
    passwordTask = Task { [weak self] in
      guard let self else {
        return
      }
      do {
        try await passwordStore.removePassword(for: identity)
        guard !Task.isCancelled, !isTornDown else {
          return
        }
        hasSavedPassword = false
      } catch {
        guard !Task.isCancelled, !isTornDown else {
          return
        }
        present(error, title: "Saved Password Could Not Be Removed")
      }
    }
  }

  func goToSearchResult(_ result: PDFSearchResult) {
    guard let selection = searchService.selection(for: result) else {
      viewer.go(toPageIndex: result.pageIndex)
      return
    }
    viewer.go(to: selection)
  }

  func tearDown() {
    guard !isTornDown else {
      return
    }
    isTornDown = true
    saveStateNow()
    accessTask?.cancel()
    unlockTask?.cancel()
    passwordTask?.cancel()
    searchTask?.cancel()
    stateSaveTask?.cancel()
    searchService.tearDown()
    viewer.detach()
    Task { [thumbnailService] in
      await thumbnailService.tearDown()
    }
  }

  private func prepareAccess() async {
    guard !Task.isCancelled, !isTornDown else {
      return
    }
    guard document.isLocked else {
      finishUnlock()
      return
    }

    do {
      if let storedPassword = try await passwordStore.password(for: identity) {
        guard !Task.isCancelled, !isTornDown else {
          return
        }
        if document.unlock(withPassword: storedPassword) {
          await prepareThumbnails(password: storedPassword)
          guard !Task.isCancelled, !isTornDown else {
            return
          }
          hasSavedPassword = true
          finishUnlock()
          return
        }

        try await passwordStore.removePassword(for: identity)
        hasSavedPassword = false
      }
      guard !Task.isCancelled, !isTornDown else {
        return
      }
      accessState = .locked
      isPasswordPromptPresented = true
    } catch {
      guard !Task.isCancelled, !isTornDown else {
        return
      }
      accessState = .locked
      present(error, title: "Keychain Error")
      isPasswordPromptPresented = true
    }
  }

  private func prepareThumbnails(password: String) async {
    do {
      try await thumbnailService.unlock(withPassword: password)
    } catch {
      guard !Task.isCancelled, !isTornDown else {
        return
      }
      present(error, title: "Thumbnails Could Not Be Unlocked")
    }
  }

  private func finishUnlock() {
    guard document.pageCount > 0 else {
      failureMessage = "The PDF was unlocked, but it contains no readable pages."
      accessState = .failed
      isPasswordPromptPresented = false
      return
    }
    outline = PDFOutlineBuilder.build(document: document)
    let restored: ReaderState
    do {
      restored = (try stateStore.state(for: identity) ?? ReaderState())
        .normalized(pageCount: pageCount)
    } catch {
      restored = ReaderState().normalized(pageCount: pageCount)
      present(error, title: "Reading Position Could Not Be Restored")
    }
    layout = restored.layout
    // The search query isn't persisted, so never reopen onto an empty Search section.
    sidebarSection = restored.sidebarSection == .search ? .thumbnails : restored.sidebarSection
    sidebarVisible = restored.sidebarVisible
    viewer.restore(restored)
    accessState = .ready
  }

  private func scheduleStateSave() {
    guard accessState == .ready, !isTornDown else {
      return
    }
    stateSaveTask?.cancel()
    stateSaveTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else {
        return
      }
      self?.saveStateNow()
    }
  }

  private func saveStateNow() {
    guard accessState == .ready else {
      return
    }
    let state = ReaderState(
      pageIndex: viewer.currentPageIndex,
      autoScales: viewer.autoScales,
      scaleFactor: viewer.scaleFactor,
      layout: layout,
      sidebarSection: browsingSection,
      sidebarVisible: sidebarVisible
    )
    do {
      try stateStore.save(state, for: identity)
    } catch {
      // Report once per document; repeating on every page turn would be noise.
      guard !didPresentStatePersistenceError else {
        return
      }
      didPresentStatePersistenceError = true
      present(error, title: "Reading Position Could Not Be Saved")
    }
  }

  private func present(_ error: Error, title: String) {
    presentedError = PresentedError(
      title: title,
      message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    )
  }
}
