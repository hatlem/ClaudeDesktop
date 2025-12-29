import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if appState.currentConversation != nil {
                ChatView()
            } else {
                Text("Velg en samtale")
                    .foregroundColor(.secondary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { appState.newConversation() }) {
                    Image(systemName: "square.and.pencil")
                }
                .help("Ny samtale")
            }

            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $appState.isComputerControlEnabled) {
                    HStack(spacing: 4) {
                        Image(systemName: appState.isComputerControlEnabled ? "keyboard.badge.eye" : "keyboard")
                        Text(appState.isComputerControlEnabled ? "Aktiv" : "Computer Use")
                    }
                }
                .toggleStyle(.button)
                .tint(appState.isComputerControlEnabled ? .green : .secondary)
                .help("Aktiver/deaktiver computer control")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                }
                .help("Innstillinger")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(width: 400, height: 200)
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: Binding(
            get: { appState.currentConversation?.id },
            set: { id in
                appState.currentConversation = appState.conversations.first { $0.id == id }
            }
        )) {
            ForEach(appState.conversations) { conversation in
                NavigationLink(value: conversation.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conversation.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(conversation.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Claude")
    }
}
