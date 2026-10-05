import AppKit
import KeelCore
import PDFKit
import SwiftUI

struct ReaderRootView: View {
  @ObservedObject var model: ReaderViewModel
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @FocusState private var isSearchFocused: Bool
  @AppStorage(ReaderPreferences.darkPagesKey) private var darkPages = false

  var body: some View {
    Group {
      switch model.accessState {
      case .preparing:
        ProgressView("Opening PDF…")
          .controlSize(.large)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .locked:
        lockedContent
      case .ready:
        readerContent
      case .failed:
        ContentUnavailableView(
          "PDF Could Not Be Read",
          systemImage: "doc.badge.ellipsis",
          description: Text(model.failureMessage)
        )
      }
    }
    .frame(minWidth: 720, minHeight: 520)
    .background(.background)
    .task {
      model.prepare()
    }
    .sheet(isPresented: $model.isPasswordPromptPresented) {
      PasswordPromptView(
        documentName: model.sourceURL.lastPathComponent,
        validationMessage: model.passwordError,
        onUnlock: model.unlock(password:remember:),
        onCancel: {
          model.isPasswordPromptPresented = false
        }
      )
    }
    .alert(item: $model.presentedError) { error in
      Alert(
        title: Text(error.title),
        message: Text(error.message),
        dismissButton: .default(Text("OK"))
      )
    }
    .dropDestination(for: URL.self) { urls, _ in
      DocumentOpener.openDroppedPDFs(urls)
    }
  }

  private var lockedContent: some View {
    ContentUnavailableView {
      Label("PDF Locked", systemImage: "lock.fill")
    } description: {
      Text("Enter the document password to read this PDF.")
    } actions: {
      Button("Enter Password…") {
        model.isPasswordPromptPresented = true
      }
      .keyboardShortcut(.defaultAction)
    }
  }

  private var readerContent: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      ReaderSidebar(model: model)
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 420)
    } detail: {
      PDFViewRepresentable(
        document: model.document,
        layout: model.layout,
        showsCoverSeparately: model.showsCoverSeparately,
        darkPages: darkPages,
        controller: model.viewer
      )
      .ignoresSafeArea(.container, edges: .bottom)
    }
    .navigationSplitViewStyle(.balanced)
    .searchable(
      text: $model.searchQuery,
      placement: .toolbar,
      prompt: "Search PDF"
    )
    .searchFocused($isSearchFocused)
    .onChange(of: model.focusRequest, initial: true) { _, request in
      guard request == .search else {
        return
      }
      isSearchFocused = true
      model.focusRequest = nil
    }
    .onChange(of: model.searchQuery) {
      model.updateSearchQuery()
    }
    .onChange(of: columnVisibility) { _, newValue in
      model.sidebarVisible = newValue != .detailOnly
    }
    .onChange(of: model.sidebarVisible) { _, isVisible in
      columnVisibility = isVisible ? .all : .detailOnly
    }
    .toolbar {
      ReaderToolbar(model: model)
      ReaderShareToolbar(model: model)
    }
  }
}

private struct ReaderShareToolbar: ToolbarContent {
  let model: ReaderViewModel

  var body: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      ShareLink(item: model.sourceURL)
        .help("Share")
    }
  }
}

private struct ReaderToolbar: ToolbarContent {
  @ObservedObject var model: ReaderViewModel
  @ObservedObject private var viewer: PDFViewController
  @State private var pageText = ""
  @FocusState private var isPageFieldFocused: Bool

  init(model: ReaderViewModel) {
    self.model = model
    viewer = model.viewer
  }

  var body: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button(action: viewer.previousPage) {
        Label("Previous Page", systemImage: "chevron.up")
      }
      .disabled(viewer.currentPageIndex <= 0)
      .help("Previous page")

      Button(action: viewer.nextPage) {
        Label("Next Page", systemImage: "chevron.down")
      }
      .disabled(viewer.currentPageIndex >= model.pageCount - 1)
      .help("Next page")

      HStack(spacing: 5) {
        TextField("Page", text: $pageText)
          .textFieldStyle(.roundedBorder)
          .multilineTextAlignment(.trailing)
          .frame(width: 48)
          .focused($isPageFieldFocused)
          .accessibilityLabel("Current page")
          .onSubmit {
            if let page = Int(pageText), (1...model.pageCount).contains(page) {
              viewer.go(toPageIndex: page - 1)
            } else {
              showCurrentPage()
              NSSound.beep()
            }
          }
        Text("of \(model.pageCount)")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      // `initial` matters: a restored position can change the page before the first render.
      .onChange(of: viewer.currentPageIndex, initial: true) {
        showCurrentPage()
      }
      .onChange(of: isPageFieldFocused) { _, isFocused in
        if !isFocused {
          showCurrentPage()
        }
      }
      .onChange(of: model.focusRequest, initial: true) { _, request in
        guard request == .pageField else {
          return
        }
        isPageFieldFocused = true
        model.focusRequest = nil
      }
      .accessibilityElement(children: .contain)

      Button(action: viewer.zoomOut) {
        Label("Zoom Out", systemImage: "minus.magnifyingglass")
      }
      .help("Zoom out")

      Button(action: viewer.zoomIn) {
        Label("Zoom In", systemImage: "plus.magnifyingglass")
      }
      .help("Zoom in")

      Menu {
        Button("Zoom to Fit", action: viewer.zoomToFit)
        Button("Actual Size", action: viewer.actualSize)
        Button("Fit Width", action: viewer.fitToWidth)
      } label: {
        Text(viewer.scaleFactor, format: .percent.precision(.fractionLength(0)))
          .monospacedDigit()
      }
      .accessibilityLabel("Zoom")
      .help("Zoom options")

      Menu {
        Picker("Page Layout", selection: $model.layout) {
          ForEach(ReaderLayout.allCases, id: \.self) { layout in
            Label(layout.title, systemImage: layout.symbolName)
              .tag(layout)
          }
        }
        .pickerStyle(.inline)
        Divider()
        Toggle("Show Cover Separately", isOn: $model.showsCoverSeparately)
          .disabled(!model.layout.isTwoPage)
      } label: {
        Label(model.layout.title, systemImage: model.layout.symbolName)
      }
      .accessibilityLabel("Page layout")
      .help("Choose the page layout")

      Menu {
        Button("Forget Saved Password", role: .destructive) {
          model.forgetSavedPassword()
        }
        .disabled(!model.hasSavedPassword)
      } label: {
        Label("Document Options", systemImage: "ellipsis.circle")
      }
      .help("Document options")
    }
  }

  private func showCurrentPage() {
    pageText = String(viewer.currentPageIndex + 1)
  }
}
