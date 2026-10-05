import AppKit
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
    }
  }
}

private struct DocumentCommands: Commands {
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

private struct SettingsView: View {
  var body: some View {
    ContentUnavailableView(
      "No Settings",
      systemImage: "sailboat",
      description: Text("Keel uses native macOS reading and accessibility settings.")
    )
    .frame(width: 420, height: 240)
    .padding()
  }
}
