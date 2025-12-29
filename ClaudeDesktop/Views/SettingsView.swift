import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var tempApiKey = ""
    @State private var showApiKey = false

    var body: some View {
        Form {
            Section {
                HStack {
                    if showApiKey {
                        TextField("API-nokkel", text: $tempApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API-nokkel", text: $tempApiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showApiKey.toggle() }) {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                Text("Hent din API-nokkel fra console.anthropic.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Anthropic API")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Screen Recording", systemImage: hasScreenRecordingPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasScreenRecordingPermission ? .green : .red)

                    Label("Accessibility", systemImage: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .red)

                    if !hasScreenRecordingPermission || !hasAccessibilityPermission {
                        Button("Apne Systeminnstillinger") {
                            openSystemPreferences()
                        }
                        .padding(.top, 4)
                    }
                }
            } header: {
                Text("Tillatelser for Computer Use")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 400)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lagre") {
                    appState.apiKey = tempApiKey
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") {
                    dismiss()
                }
            }
        }
        .onAppear {
            tempApiKey = appState.apiKey
        }
    }

    private var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    private var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
