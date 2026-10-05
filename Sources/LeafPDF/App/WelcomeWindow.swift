import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
  static let shared = WelcomeWindowController()

  private let hostingController = NSHostingController(rootView: WelcomeView(recentURLs: []))
  private var documentWindowObserver: NSObjectProtocol?

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "Welcome to Leaf PDF"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.tabbingMode = .disallowed
    window.isRestorable = false
    window.contentViewController = hostingController
    window.setContentSize(NSSize(width: 680, height: 420))
    super.init(window: window)
    window.delegate = self

    documentWindowObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeMainNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      let isDocumentWindow =
        (notification.object as? NSWindow)?.windowController?.document is LeafPDFDocument
      guard isDocumentWindow else {
        return
      }
      MainActor.assumeIsolated {
        self?.close()
      }
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    hostingController.rootView = WelcomeView(
      recentURLs: Array(NSDocumentController.shared.recentDocumentURLs.prefix(8))
    )
    if window?.isVisible != true {
      window?.center()
    }
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}

enum DocumentOpener {
  @MainActor
  static func open(_ url: URL) {
    NSDocumentController.shared.openDocument(withContentsOf: url, display: true) {
      _, _, error in
      if let error {
        NSApplication.shared.presentError(error)
      }
    }
  }
}

private struct WelcomeView: View {
  let recentURLs: [URL]

  @State private var isDropTargeted = false

  var body: some View {
    HStack(spacing: 0) {
      introduction
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      RecentDocumentsList(urls: recentURLs)
        .frame(width: 280)
    }
    .frame(width: 680, height: 420)
    .ignoresSafeArea()
    .dropDestination(for: URL.self) { urls, _ in
      let pdfs = urls.filter { url in
        (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.conforms(to: .pdf)
          ?? false
      }
      pdfs.forEach(DocumentOpener.open)
      return !pdfs.isEmpty
    } isTargeted: { isDropTargeted = $0 }
  }

  private var introduction: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(nsImage: NSApplication.shared.applicationIconImage)
        .resizable()
        .frame(width: 112, height: 112)
        .accessibilityHidden(true)
      Text("Leaf PDF")
        .font(.largeTitle.weight(.semibold))
      Text("A focused, native PDF reader")
        .foregroundStyle(.secondary)
      Button {
        NSDocumentController.shared.openDocument(nil)
      } label: {
        Label("Open PDF…", systemImage: "folder")
          .frame(minWidth: 160)
      }
      .controlSize(.large)
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.defaultAction)
      .padding(.top, 10)
      Spacer()
      Label(
        isDropTargeted ? "Release to open" : "Or drop a PDF onto this window",
        systemImage: "arrow.down.doc"
      )
      .font(.callout)
      .foregroundStyle(isDropTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
      .padding(.bottom, 24)
    }
    .padding(.horizontal, 32)
    .background {
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        .padding(12)
        .opacity(isDropTargeted ? 1 : 0)
    }
    .animation(.easeOut(duration: 0.15), value: isDropTargeted)
  }
}

private struct RecentDocumentsList: View {
  let urls: [URL]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Recent")
        .font(.headline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .padding(.bottom, 8)

      if urls.isEmpty {
        ContentUnavailableView(
          "No Recent Documents",
          systemImage: "clock",
          description: Text("PDFs you open will appear here.")
        )
        .frame(maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(urls, id: \.self) { url in
              RecentDocumentRow(url: url)
            }
          }
          .padding(.horizontal, 10)
          .padding(.bottom, 12)
        }
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.regularMaterial)
  }
}

private struct RecentDocumentRow: View {
  let url: URL

  @State private var isHovered = false

  var body: some View {
    Button {
      DocumentOpener.open(url)
    } label: {
      HStack(spacing: 10) {
        Image(nsImage: NSWorkspace.shared.icon(for: .pdf))
          .resizable()
          .frame(width: 28, height: 28)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(url.deletingPathExtension().lastPathComponent)
            .lineLimit(1)
            .truncationMode(.middle)
          Text(abbreviatedFolder)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.head)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
      )
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help(url.path)
    .accessibilityLabel("Open \(url.lastPathComponent)")
  }

  private var abbreviatedFolder: String {
    (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
  }
}
