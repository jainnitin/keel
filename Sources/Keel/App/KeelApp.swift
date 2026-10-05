import AppKit
import KeelCore
import SwiftUI

@main
struct KeelApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView()
    }
    .commands {
      DocumentCommands()
      ReaderCommands()
    }
  }
}

private struct DocumentCommands: Commands {
  @ObservedObject private var activeReader = ActiveReader.shared

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button("Open…") {
        NSDocumentController.shared.openDocument(nil)
      }
      .keyboardShortcut("o", modifiers: .command)

      Menu("Open Recent") {
        let recentURLs = Array(NSDocumentController.shared.recentDocumentURLs.prefix(10))
        if recentURLs.isEmpty {
          Text("No Recent Documents")
        } else {
          ForEach(recentURLs, id: \.self) { url in
            Button(url.lastPathComponent) {
              DocumentOpener.open(url)
            }
          }
          Divider()
          Button("Clear Menu") {
            NSDocumentController.shared.clearRecentDocuments(nil)
          }
        }
      }
    }

    CommandGroup(replacing: .saveItem) {}

    CommandGroup(replacing: .printItem) {
      Button("Print…") {
        NSApp.sendAction(#selector(NSDocument.printDocument(_:)), to: nil, from: nil)
      }
      .keyboardShortcut("p", modifiers: .command)
      .disabled(activeReader.model == nil)
    }

    CommandGroup(before: .windowList) {
      Button("Welcome to Keel") {
        WelcomeWindowController.shared.show()
      }
      .keyboardShortcut("1", modifiers: [.command, .shift])
      Divider()
    }
  }
}

/// Reader commands, which act on the main window's reader through `ActiveReader`.
private struct ReaderCommands: Commands {
  @ObservedObject private var activeReader = ActiveReader.shared
  @AppStorage(ReaderPreferences.darkPagesKey) private var darkPages = false

  private var model: ReaderViewModel? {
    activeReader.model
  }

  var body: some Commands {
    CommandGroup(replacing: .textEditing) {
      Menu("Find") {
        Button("Find…") {
          model?.focusRequest = .search
        }
        .keyboardShortcut("f", modifiers: .command)
        Button("Find Next") {
          model?.showSearchResult(offset: 1)
        }
        .keyboardShortcut("g", modifiers: .command)
        Button("Find Previous") {
          model?.showSearchResult(offset: -1)
        }
        .keyboardShortcut("g", modifiers: [.command, .shift])
      }
      .disabled(model == nil)
    }

    CommandGroup(replacing: .sidebar) {
      Button(model?.sidebarVisible == true ? "Hide Sidebar" : "Show Sidebar") {
        model?.toggleSidebar()
      }
      .keyboardShortcut("s", modifiers: [.command, .control])
      .disabled(model == nil)
    }

    CommandGroup(before: .toolbar) {
      Group {
        Button("Zoom In") {
          model?.viewer.zoomIn()
        }
        .keyboardShortcut("+", modifiers: .command)
        Button("Zoom Out") {
          model?.viewer.zoomOut()
        }
        .keyboardShortcut("-", modifiers: .command)
        Button("Actual Size") {
          model?.viewer.actualSize()
        }
        .keyboardShortcut("0", modifiers: .command)
        Button("Zoom to Fit") {
          model?.viewer.zoomToFit()
        }
        .keyboardShortcut("9", modifiers: .command)
        Button("Fit Width") {
          model?.viewer.fitToWidth()
        }
        .keyboardShortcut("9", modifiers: [.command, .option])
      }
      .disabled(model == nil)
      Divider()
      Picker("Page Layout", selection: layout) {
        ForEach(ReaderLayout.allCases, id: \.self) { layout in
          Text(layout.title).tag(layout)
        }
      }
      .pickerStyle(.inline)
      .labelsHidden()
      .disabled(model == nil)
      Toggle("Show Cover Separately", isOn: showsCover)
        .disabled(model?.layout.isTwoPage != true)
      Toggle("Dark Pages", isOn: $darkPages)
        .keyboardShortcut("d", modifiers: [.command, .shift])
      Divider()
    }

    CommandMenu("Go") {
      Button("Previous Page") {
        model?.viewer.previousPage()
      }
      .keyboardShortcut(.upArrow, modifiers: .option)
      .disabled((model?.viewer.currentPageIndex ?? 0) <= 0)
      Button("Next Page") {
        model?.viewer.nextPage()
      }
      .keyboardShortcut(.downArrow, modifiers: .option)
      .disabled(model.map { $0.viewer.currentPageIndex >= $0.pageCount - 1 } ?? true)
      Button("Go to Page…") {
        model?.focusRequest = .pageField
      }
      .keyboardShortcut("g", modifiers: [.command, .option])
      .disabled(model == nil)
      Divider()
      Button("Back") {
        model?.viewer.goBack()
      }
      .keyboardShortcut("[", modifiers: .command)
      .disabled(model?.viewer.canGoBack != true)
      Button("Forward") {
        model?.viewer.goForward()
      }
      .keyboardShortcut("]", modifiers: .command)
      .disabled(model?.viewer.canGoForward != true)
    }
  }

  private var showsCover: Binding<Bool> {
    Binding(
      get: { model?.showsCoverSeparately ?? false },
      set: { model?.showsCoverSeparately = $0 }
    )
  }

  private var layout: Binding<ReaderLayout> {
    Binding(
      get: { model?.layout ?? .continuous },
      set: { model?.layout = $0 }
    )
  }
}

private struct SettingsView: View {
  @AppStorage(ReaderPreferences.darkPagesKey) private var darkPages = false

  var body: some View {
    Form {
      Toggle(isOn: $darkPages) {
        Text("Dark pages")
        Text("Show pages light-on-dark for reading at night. The PDF itself isn’t changed.")
      }
    }
    .formStyle(.grouped)
    .frame(width: 420)
    .fixedSize(horizontal: false, vertical: true)
  }
}
