import AppKit
import KeelCore
import PDFKit
import SwiftUI

struct ReaderRootView: View {
  @ObservedObject var model: ReaderViewModel
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
    }
  }
}

private struct ReaderToolbar: ToolbarContent {
  @ObservedObject var model: ReaderViewModel
  @ObservedObject private var viewer: PDFViewController
  @State private var pageText: String

  init(model: ReaderViewModel) {
    self.model = model
    viewer = model.viewer
    _pageText = State(initialValue: String(model.viewer.currentPageIndex + 1))
  }

  var body: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button(action: viewer.previousPage) {
        Label("Previous Page", systemImage: "chevron.up")
      }
      .disabled(viewer.currentPageIndex <= 0)
      .help("Previous page")
      .keyboardShortcut(.pageUp, modifiers: [])

      Button(action: viewer.nextPage) {
        Label("Next Page", systemImage: "chevron.down")
      }
      .disabled(viewer.currentPageIndex >= model.pageCount - 1)
      .help("Next page")
      .keyboardShortcut(.pageDown, modifiers: [])

      HStack(spacing: 5) {
        TextField("Page", text: $pageText)
          .textFieldStyle(.roundedBorder)
          .multilineTextAlignment(.trailing)
          .frame(width: 48)
          .accessibilityLabel("Current page")
          .onSubmit {
            if let page = Int(pageText), (1...model.pageCount).contains(page) {
              viewer.go(toPageIndex: page - 1)
            } else {
              pageText = String(viewer.currentPageIndex + 1)
              NSSound.beep()
            }
          }
        Text("of \(model.pageCount)")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      .onChange(of: viewer.currentPageIndex) { _, pageIndex in
        pageText = String(pageIndex + 1)
      }
      .accessibilityElement(children: .contain)

      Button(action: viewer.zoomOut) {
        Label("Zoom Out", systemImage: "minus.magnifyingglass")
      }
      .help("Zoom out")
      .keyboardShortcut("-", modifiers: .command)

      Button(action: viewer.zoomIn) {
        Label("Zoom In", systemImage: "plus.magnifyingglass")
      }
      .help("Zoom in")
      .keyboardShortcut("+", modifiers: .command)

      Menu {
        Button("Actual Size", action: viewer.actualSize)
          .keyboardShortcut("0", modifiers: .command)
        Button("Fit to Width", action: viewer.fitToWidth)
          .keyboardShortcut("9", modifiers: .command)
      } label: {
        Label("Zoom Options", systemImage: "magnifyingglass")
      }
      .help("Zoom options")

      Picker("Page Layout", selection: $model.layout) {
        Label("Continuous", systemImage: "rectangle.stack")
          .accessibilityLabel("Continuous scrolling")
          .tag(ReaderLayout.continuous)
        Label("Single Page", systemImage: "rectangle")
          .accessibilityLabel("Single page")
          .tag(ReaderLayout.singlePage)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .help("Choose continuous or single-page layout")

      Menu {
        Button("Copy Link to Page", action: model.copyLinkToCurrentPage)
          .keyboardShortcut("c", modifiers: [.command, .option])
        Divider()
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
}
