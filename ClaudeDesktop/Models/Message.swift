import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    var toolUse: ToolUse?

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), toolUse: ToolUse? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolUse = toolUse
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ToolUse: Codable {
    let type: String
    let action: ComputerAction?
}

struct Conversation: Identifiable {
    let id: UUID
    var title: String
    var messages: [Message]
    let createdAt: Date

    init(id: UUID = UUID(), title: String, messages: [Message] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
    }
}
