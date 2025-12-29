import Foundation

struct ComputerAction: Codable {
    let action: ActionType
    let coordinate: [Int]?
    let text: String?

    enum ActionType: String, Codable {
        case screenshot
        case mouse_move
        case left_click
        case right_click
        case double_click
        case left_click_drag
        case middle_click
        case type
        case key
        case scroll
        case cursor_position
    }
}

struct ComputerToolResult: Codable {
    let type: String
    let toolUseId: String
    let content: [ToolResultContent]

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content
    }
}

struct ToolResultContent: Codable {
    let type: String
    let source: ImageSource?
    let text: String?
}

struct ImageSource: Codable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}
