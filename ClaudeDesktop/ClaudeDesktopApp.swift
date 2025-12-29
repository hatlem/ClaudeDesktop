import SwiftUI

@main
struct ClaudeDesktopApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "anthropic_api_key")
        }
    }
    @Published var isComputerControlEnabled: Bool = false
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        // Create a default conversation
        let defaultConversation = Conversation(title: "Ny samtale")
        self.conversations = [defaultConversation]
        self.currentConversation = defaultConversation
    }

    func newConversation() {
        let conversation = Conversation(title: "Ny samtale")
        conversations.insert(conversation, at: 0)
        currentConversation = conversation
    }
}
