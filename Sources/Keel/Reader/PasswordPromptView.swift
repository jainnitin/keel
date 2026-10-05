import SwiftUI

struct PasswordPromptView: View {
  let documentName: String
  let validationMessage: String?
  let onUnlock: (String, Bool) -> Void
  let onCancel: () -> Void

  @State private var password = ""
  @State private var remember = false
  @FocusState private var passwordFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: "lock.doc.fill")
          .font(.system(size: 30))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
          Text("Password Required")
            .font(.title3.weight(.semibold))
          Text("“\(documentName)” is encrypted.")
            .foregroundStyle(.secondary)
        }
      }

      SecureField("Password", text: $password)
        .textFieldStyle(.roundedBorder)
        .focused($passwordFocused)
        .accessibilityLabel("PDF password")
        .onSubmit(submit)

      if let validationMessage {
        Label(validationMessage, systemImage: "exclamationmark.circle.fill")
          .font(.callout)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Error: \(validationMessage)")
      }

      Toggle("Remember this password in Keychain", isOn: $remember)
        .help("The password is stored using standard macOS Keychain protection.")

      HStack {
        Spacer()
        Button("Cancel", action: onCancel)
          .keyboardShortcut(.cancelAction)
        Button("Unlock", action: submit)
          .keyboardShortcut(.defaultAction)
          .disabled(password.isEmpty)
      }
    }
    .padding(22)
    .frame(width: 420)
    .onAppear {
      passwordFocused = true
    }
  }

  private func submit() {
    onUnlock(password, remember)
  }
}
