import AppKit
import Foundation
import LeafPDFCore
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
  private let passwordCoordinator: PasswordCoordinator
  private let stateStore: ReaderStateStore
  private var accessTask: Task<Void, Never>?
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
    self.passwordCoordinator = PasswordCoordinator(store: passwordStore)
    self.stateStore = stateStore
    searchService = PDFSearchService(document: document)
    thumbnailService = ThumbnailService(url: sourceURL)
    viewer.onStateChange = { [weak self] _, _ in
      self?.scheduleStateSave()
    }
  }

  var pageCount: Int {
    document.pageCount
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
    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      sidebarSection = .search
      sidebarVisible = true
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
    finishUnlock()
    guard remember else {
      return
    }

    passwordTask?.cancel()
    passwordTask = Task { [weak self] in
      guard let self else {
        return
      }
      do {
        try await passwordCoordinator.remember(password, for: identity)
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

  func forgetSavedPassword() {
    passwordTask?.cancel()
    passwordTask = Task { [weak self] in
      guard let self else {
        return
      }
      do {
        try await passwordCoordinator.forget(identity)
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

  func openDroppedPDF(_ url: URL) {
    NSDocumentController.shared.openDocument(
      withContentsOf: url,
      display: true
    ) { [weak self] _, _, error in
      if let error {
        Task { @MainActor [weak self] in
          self?.present(error, title: "PDF Could Not Be Opened")
        }
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
    passwordTask?.cancel()
    searchTask?.cancel()
    stateSaveTask?.cancel()
    searchService.tearDown()
    viewer.detach()
    Task { [thumbnailService] in
      await thumbnailService.removeAll()
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
      if let storedPassword = try await passwordCoordinator.storedPassword(for: identity) {
        guard !Task.isCancelled, !isTornDown else {
          return
        }
        if document.unlock(withPassword: storedPassword) {
          hasSavedPassword = true
          finishUnlock()
          return
        }

        try await passwordCoordinator.forget(identity)
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
    sidebarSection = restored.sidebarSection
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
      scaleFactor: viewer.scaleFactor,
      layout: layout,
      sidebarSection: sidebarSection,
      sidebarVisible: sidebarVisible
    )
    do {
      try stateStore.save(state, for: identity)
    } catch  where !didPresentStatePersistenceError {
      didPresentStatePersistenceError = true
      present(error, title: "Reading Position Could Not Be Saved")
    } catch {
      return
    }
  }

  private func present(_ error: Error, title: String) {
    presentedError = PresentedError(
      title: title,
      message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    )
  }
}
