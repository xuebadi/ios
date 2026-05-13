import Foundation
import UIKit

/// Represents a single message in a conversation
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let image: Data?
    let audioURL: URL?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        image: UIImage? = nil,
        audioURL: URL? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.image = image?.jpegData(compressionQuality: 0.8)
        self.audioURL = audioURL
        self.timestamp = timestamp
    }

    var uiImage: UIImage? {
        guard let data = image else { return nil }
        return UIImage(data: data)
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case thinking  // for deep-think mode
}

/// Downloaded / available local model info
struct LocalModelInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let size: String        // e.g. "1.8 GB"
    let params: String      // e.g. "3B"
    let quantization: String // e.g. "INT4"
    let isDownloaded: Bool
    let tags: [String]
    let categories: [String]
    let vendor: String
    let sources: [String: String]  // source name -> path

    init(
        id: UUID = UUID(),
        name: String,
        size: String,
        params: String,
        quantization: String,
        isDownloaded: Bool = false,
        tags: [String] = [],
        categories: [String] = [],
        vendor: String = "MNN",
        sources: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.params = params
        self.quantization = quantization
        self.isDownloaded = isDownloaded
        self.tags = tags
        self.categories = categories
        self.vendor = vendor
        self.sources = sources
    }
}

/// Model config (runtime params)
struct ModelConfig: Codable {
    var backendType: BackendType = .metal  // or .cpu
    var threadNum: Int = 4
    var precision: Precision = .normal
    var temperature: Double = 0.7
    var topP: Double = 0.9
    var topK: Int = 40
    var maxNewTokens: Int = 2048
    var reuseKV: Bool = true
    var mmapEnabled: Bool = true
    var samplerType: SamplerType = .mixed
}

enum BackendType: String, Codable, CaseIterable {
    case cpu = "CPU"
    case metal = "Metal (GPU)"
    case opencl = "OpenCL"
}

enum Precision: String, Codable, CaseIterable {
    case low = "FP16 / Low"
    case normal = "Normal"
    case high = "FP32 / High"
}

enum SamplerType: String, Codable, CaseIterable {
    case greedy = "Greedy"
    case topK = "Top-K"
    case topP = "Top-P"
    case mixed = "Mixed"
}

/// A conversation session
struct Conversation: Identifiable, Codable {
    let id: UUID
    var modelName: String
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        modelName: String = "Qwen2.5-VL-3B-Instruct",
        title: String = "新对话",
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.modelName = modelName
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
