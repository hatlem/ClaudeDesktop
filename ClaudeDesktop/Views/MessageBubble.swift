import SwiftUI

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            if message.role == .assistant {
                // Claude avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)

                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let toolUse = message.toolUse {
                    // Tool use indicator
                    HStack(spacing: 6) {
                        Image(systemName: "cursorarrow.click.2")
                            .font(.caption)
                        Text(toolUse.action?.action.rawValue ?? "action")
                            .font(.caption)

                        if let coord = toolUse.action?.coordinate {
                            Text("(\(coord[0]), \(coord[1]))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !message.content.isEmpty && message.toolUse == nil {
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.role == .user
                                ? Color.accentColor
                                : Color(nsColor: .controlBackgroundColor)
                        )
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .user {
                // User avatar
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 32, height: 32)

                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}

#Preview {
    VStack {
        MessageBubble(message: Message(role: .user, content: "Hei Claude! Kan du hjelpe meg?"))
        MessageBubble(message: Message(role: .assistant, content: "Hei! Selvfolgelig kan jeg hjelpe deg. Hva trenger du?"))
        MessageBubble(message: Message(
            role: .assistant,
            content: "",
            toolUse: ToolUse(type: "computer", action: ComputerAction(action: .left_click, coordinate: [100, 200], text: nil))
        ))
    }
    .padding()
    .frame(width: 500)
}
