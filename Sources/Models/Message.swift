import Foundation
import SwiftUI

// MARK: - 聊天消息模型
struct Message: Identifiable, Equatable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var imageData: Data?
    var audioData: Data?
    var isStreaming: Bool
    var isThinking: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        imageData: Data? = nil,
        audioData: Data? = nil,
        isStreaming: Bool = false,
        isThinking: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.imageData = imageData
        self.audioData = audioData
        self.isStreaming = isStreaming
        self.isThinking = isThinking
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - 对话会话
struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    var modelId: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "新对话",
        messages: [Message] = [],
        modelId: String = "Qwen2.5-VL-3B-Instruct",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.modelId = modelId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 模型信息
struct ModelInfo: Identifiable, Codable {
    let id: String
    let name: String
    let size: String
    let parameters: String
    let quantization: String
    let downloadURL: String
    let category: ModelCategory
    let tags: [String]
    var isDownloaded: Bool
    var localPath: String?

    enum ModelCategory: String, Codable, CaseIterable {
        case text = "文本模型"
        case vision = "视觉模型"
        case audio = "音频模型"
        case omni = "全模态"
        case local = "本地模型"
    }
}

// MARK: - 生成配置
struct GenerationConfig: Codable {
    var maxNewTokens: Int = 2048
    var temperature: Double = 0.7
    var topP: Double = 0.9
    var topK: Int = 50
    var repeatPenalty: Double = 1.1
    var streamInterval: Int = 3  // 每N个token刷新一次UI

    static let `default` = GenerationConfig()

    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - 应用设置
struct AppSettings: Codable {
    var selectedModelId: String = "Qwen2.5-VL-3B-Instruct"
    var backendType: BackendType = .metal
    var threadCount: Int = 4
    var precision: Precision = .normal
    var enableMMap: Bool = true
    var generationConfig: GenerationConfig = .default
    var enableMarkdown: Bool = true
    var enableThinking: Bool = false
    var audioOutput: Bool = true

    enum BackendType: String, Codable, CaseIterable {
        case cpu = "CPU"
        case metal = "Metal GPU"

        var displayName: String { rawValue }
    }

    enum Precision: String, Codable, CaseIterable {
        case low = "低 (FP16)"
        case normal = "标准 (INT8)"
        case high = "高精度 (FP32)"

        var displayName: String { rawValue }
    }
}

// MARK: - 聊天上下文标签
enum ChatContextTag {
    static let image = "<img>"
    static let audio = "<audio>"
    static let video = "<video>"
    static let thinkingStart = "<think>"
    static let thinkingEnd = "</think>"
}
