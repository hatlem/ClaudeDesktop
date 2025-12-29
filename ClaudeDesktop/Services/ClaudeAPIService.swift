import Foundation
import AppKit

class ClaudeAPIService {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    func sendMessage(messages: [Message], apiKey: String, computerUseEnabled: Bool) async throws -> ClaudeResponse {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        if computerUseEnabled {
            request.setValue("computer-use-2024-10-22", forHTTPHeaderField: "anthropic-beta")
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": messages.filter { $0.role != .system }.map { message -> [String: Any] in
                ["role": message.role.rawValue, "content": message.content]
            }
        ]

        if computerUseEnabled {
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let screenSize = screen.frame.size

            body["tools"] = [
                [
                    "type": "computer_20241022",
                    "name": "computer",
                    "display_width_px": Int(screenSize.width),
                    "display_height_px": Int(screenSize.height),
                    "display_number": 1
                ]
            ]

            body["system"] = """
            Du har tilgang til en Mac-datamaskin gjennom computer use tool.
            Du kan ta screenshots, flytte musen, klikke, og skrive tekst.
            Brukeren har gitt deg tillatelse til a kontrollere datamaskinen deres.
            Var forsiktig og utfor kun handlinger som brukeren har bedt om.
            """
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try JSONDecoder().decode(ClaudeResponse.self, from: data)
    }

    func sendToolResult(messages: [Message], toolUseId: String, result: ToolResult, apiKey: String) async throws -> ClaudeResponse {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("computer-use-2024-10-22", forHTTPHeaderField: "anthropic-beta")

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenSize = screen.frame.size

        var apiMessages: [[String: Any]] = messages.filter { $0.role != .system }.map { message -> [String: Any] in
            ["role": message.role.rawValue, "content": message.content]
        }

        // Add tool result message
        var toolResultContent: [[String: Any]] = []

        if let imageData = result.screenshotBase64 {
            toolResultContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/png",
                    "data": imageData
                ]
            ])
        }

        if let text = result.text {
            toolResultContent.append([
                "type": "text",
                "text": text
            ])
        }

        apiMessages.append([
            "role": "user",
            "content": [
                [
                    "type": "tool_result",
                    "tool_use_id": toolUseId,
                    "content": toolResultContent
                ]
            ]
        ])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "tools": [
                [
                    "type": "computer_20241022",
                    "name": "computer",
                    "display_width_px": Int(screenSize.width),
                    "display_height_px": Int(screenSize.height),
                    "display_number": 1
                ]
            ],
            "messages": apiMessages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try JSONDecoder().decode(ClaudeResponse.self, from: data)
    }
}

// MARK: - Response Types

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id, type, role, content
        case stopReason = "stop_reason"
    }
}

enum ContentBlock: Codable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: Any])

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let inputData = try container.decode(AnyCodable.self, forKey: .input)
            self = .toolUse(id: id, name: name, input: inputData.value as? [String: Any] ?? [:])
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let name, _):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
        }
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode value"))
        }
    }
}

struct ToolResult {
    let screenshotBase64: String?
    let text: String?
}

enum ClaudeError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
