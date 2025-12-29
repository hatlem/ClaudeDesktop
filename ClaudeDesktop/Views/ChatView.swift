import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let conversation = appState.currentConversation {
                            ForEach(conversation.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        if viewModel.isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: appState.currentConversation?.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(appState.currentConversation?.messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isLoading) { _, isLoading in
                    if isLoading {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("Send en melding...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendMessage()
                        }
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.background)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            viewModel.appState = appState
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        Task {
            await viewModel.sendMessage(text)
        }
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .foregroundColor(.purple)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(dotCount % 3 == index ? 1 : 0.4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var isLoading = false
    var appState: AppState?

    private let claudeService = ClaudeAPIService()
    private let computerControl = ComputerControlService()

    func sendMessage(_ text: String) async {
        guard let appState = appState,
              var conversation = appState.currentConversation else { return }

        // Add user message
        let userMessage = Message(role: .user, content: text)
        conversation.messages.append(userMessage)
        updateConversation(conversation)

        isLoading = true
        defer { isLoading = false }

        do {
            // Send to Claude API
            let response = try await claudeService.sendMessage(
                messages: conversation.messages,
                apiKey: appState.apiKey,
                computerUseEnabled: appState.isComputerControlEnabled
            )

            // Handle response
            await handleResponse(response, conversation: &conversation)

        } catch {
            let errorMessage = Message(role: .assistant, content: "Feil: \(error.localizedDescription)")
            conversation.messages.append(errorMessage)
            updateConversation(conversation)
        }
    }

    private func handleResponse(_ response: ClaudeResponse, conversation: inout Conversation) async {
        for content in response.content {
            switch content {
            case .text(let text):
                let message = Message(role: .assistant, content: text)
                conversation.messages.append(message)
                updateConversation(conversation)

            case .toolUse(let id, let name, let input):
                if name == "computer" {
                    // Execute computer action
                    let action = try? JSONDecoder().decode(ComputerAction.self, from: JSONSerialization.data(withJSONObject: input))
                    if let action = action {
                        let actionMessage = Message(
                            role: .assistant,
                            content: "Utforer: \(action.action.rawValue)",
                            toolUse: ToolUse(type: "computer", action: action)
                        )
                        conversation.messages.append(actionMessage)
                        updateConversation(conversation)

                        // Execute the action
                        let result = await computerControl.execute(action: action)

                        // Send result back to Claude
                        guard let appState = appState else { return }
                        do {
                            let followUp = try await claudeService.sendToolResult(
                                messages: conversation.messages,
                                toolUseId: id,
                                result: result,
                                apiKey: appState.apiKey
                            )
                            await handleResponse(followUp, conversation: &conversation)
                        } catch {
                            let errorMsg = Message(role: .assistant, content: "Tool error: \(error.localizedDescription)")
                            conversation.messages.append(errorMsg)
                            updateConversation(conversation)
                        }
                    }
                }
            }
        }
    }

    private func updateConversation(_ conversation: Conversation) {
        guard let appState = appState else { return }

        if let index = appState.conversations.firstIndex(where: { $0.id == conversation.id }) {
            appState.conversations[index] = conversation
        }
        appState.currentConversation = conversation

        // Update title based on first message
        if conversation.messages.count == 1 {
            var updated = conversation
            updated.title = String(conversation.messages[0].content.prefix(30))
            if let index = appState.conversations.firstIndex(where: { $0.id == updated.id }) {
                appState.conversations[index] = updated
            }
            appState.currentConversation = updated
        }
    }
}
