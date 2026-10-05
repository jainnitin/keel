import AppKit
import SwiftUI

@main
struct LeafPDFApp: App {
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
              NSDocumentController.shared.openDocument(
                withContentsOf: url,
                display: true
              ) { _, _, error in
                if let error {
                  NSApplication.shared.presentError(error)
                }
              }
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
  }
}

private struct SettingsView: View {
  var body: some View {
    ContentUnavailableView(
      "No Settings",
      systemImage: "leaf",
      description: Text("Leaf PDF uses native macOS reading and accessibility settings.")
    )
    .frame(width: 420, height: 240)
    .padding()
  }
}
