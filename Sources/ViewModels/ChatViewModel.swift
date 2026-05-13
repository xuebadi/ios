import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published 属性
    @Published private(set) var messages: [Message] = []
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var modelName: String = "加载中..."
    @Published private(set) var tokenSpeed: Double = 0

    // MARK: - 私有属性
    private let mnnService = MNNService.shared
    private var conversations: [Conversation] = []
    private var currentConversationId: UUID?
    private var settings: AppSettings = .load()
    private var generationBuffer: String = ""
    private var thinkingBuffer: String = ""
    private var isInThinkingMode: Bool = false
    private var currentAssistantMessageId: UUID?

    // MARK: - 系统提示词
    private let systemPrompt = """
    你是一个友善、知识渊博的中文AI助手，名为"学霸帝AI"。
    你的特点：
    - 用中文回答，简洁明了
    - 善于用 Markdown 格式化回答
    - 知识涵盖科学、数学、编程、历史、文化等广泛领域
    - 遇到不确定的问题，诚实说明
    - 支持看图分析（请用 <img> 标签标记图片位置）

    回答时：
    - 使用有序列表或无序列表使内容清晰
    - 代码块使用 ``` 包裹
    - 重点内容用 **加粗**
    - 保持友好、专业的语气
    """

    // MARK: - 生命周期

    func setup() {
        // 加载历史记录
        loadConversations()

        // 注册 MNN 回调
        setupMNNCallbacks()

        // 初始化模型
        Task {
            await initializeModel()
        }
    }

    // MARK: - 模型初始化

    private func initializeModel() async {
        settings = AppSettings.load()
        modelName = settings.selectedModelId

        // 确保至少有系统消息
        if messages.isEmpty {
            let systemMessage = Message(role: .system, content: systemPrompt)
            messages.append(systemMessage)
        }

        // 尝试加载模型
        let success = await mnnService.initializeWithModelId(settings.selectedModelId)

        if !success {
            // 回退到 Demo 模式
            modelName = "🧪 Demo Mode"
            print("[ChatVM] Falling back to Demo Mode")
        } else {
            modelName = settings.selectedModelId
        }
    }

    // MARK: - 发送消息

    func sendMessage(content: String, imageData: [Data] = []) async {
        // 添加用户消息
        let userMessage = Message(
            role: .user,
            content: content,
            imageData: imageData.first
        )
        messages.append(userMessage)

        // 保存到历史
        saveCurrentConversation()

        // 清空缓冲区
        generationBuffer = ""
        thinkingBuffer = ""
        isInThinkingMode = false

        // 创建助手占位消息
        let assistantMessage = Message(
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMessage)
        currentAssistantMessageId = assistantMessage.id

        // 开始生成
        isGenerating = true

        await mnnService.generate(
            content: content,
            imageData: imageData,
            enableThinking: settings.enableThinking
        )
    }

    // MARK: - 停止生成

    func stopGeneration() {
        mnnService.stopGeneration()
        isGenerating = false

        // 保存已生成的内容
        if !generationBuffer.isEmpty {
            finalizeAssistantMessage()
        }
    }

    // MARK: - 清空聊天

    func clearChat() {
        mnnService.stopGeneration()
        messages = []
        generationBuffer = ""
        thinkingBuffer = ""
        isInThinkingMode = false

        // 重置系统消息
        let systemMessage = Message(role: .system, content: systemPrompt)
        messages.append(systemMessage)

        // 创建新对话
        currentConversationId = UUID()
    }

    // MARK: - MNN 回调

    private func setupMNNCallbacks() {
        // Token 接收回调
        mnnService.onTokenReceived = { [weak self] token in
            Task { @MainActor in
                self?.handleTokenReceived(token)
            }
        }

        // 思考模式回调
        mnnService.onThinkingReceived = { [weak self] text in
            Task { @MainActor in
                self?.handleThinkingReceived(text)
            }
        }

        // 生成完成回调
        mnnService.onComplete = { [weak self] success in
            Task { @MainActor in
                self?.handleGenerationComplete(success: success)
            }
        }
    }

    private func handleTokenReceived(_ token: String) {
        generationBuffer.append(token)

        // 检测思考模式边界
        if token.contains("<｜") || token.contains("<think>") {
            isInThinkingMode = true
        }
        if token.contains("</think>") || token.contains("｜▁") {
            isInThinkingMode = false
        }

        // 更新消息内容
        updateCurrentAssistantMessage()
    }

    private func handleThinkingReceived(_ text: String) {
        thinkingBuffer = text
        updateCurrentAssistantMessage()
    }

    private func handleGenerationComplete(success: Bool) {
        isGenerating = false

        // 更新速度显示
        tokenSpeed = mnnService.tokenSpeed

        finalizeAssistantMessage()

        // 保存对话历史
        saveCurrentConversation()
    }

    private func updateCurrentAssistantMessage() {
        guard let messageId = currentAssistantMessageId,
              let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        messages[index].content = generationBuffer
        messages[index].isThinking = isInThinkingMode
        messages[index].isStreaming = true
    }

    private func finalizeAssistantMessage() {
        guard let messageId = currentAssistantMessageId,
              let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        messages[index].content = generationBuffer
        messages[index].isStreaming = false
        messages[index].isThinking = false

        currentAssistantMessageId = nil
        generationBuffer = ""
        thinkingBuffer = ""
        isInThinkingMode = false
    }

    // MARK: - 对话历史管理

    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: "Conversations"),
              let saved = try? JSONDecoder().decode([Conversation].self, from: data) else {
            return
        }
        conversations = saved

        // 加载最新对话
        if let latest = conversations.last {
            currentConversationId = latest.id
            messages = latest.messages
        }
    }

    private func saveCurrentConversation() {
        guard let conversationId = currentConversationId else {
            currentConversationId = UUID()
            let newConversation = Conversation(
                id: currentConversationId!,
                title: messages.first(where: { $0.role == .user })?.content.prefix(20).description ?? "新对话",
                messages: messages,
                modelId: settings.selectedModelId
            )
            conversations.append(newConversation)
            persistConversations()
            return
        }

        // 更新现有对话
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].messages = messages
            conversations[index].updatedAt = Date()
            if let firstUser = messages.first(where: { $0.role == .user }) {
                conversations[index].title = String(firstUser.content.prefix(20))
            }
        }

        persistConversations()
    }

    private func persistConversations() {
        // 最多保留 50 个对话
        if conversations.count > 50 {
            conversations = Array(conversations.suffix(50))
        }

        guard let data = try? JSONEncoder().encode(conversations) else { return }
        UserDefaults.standard.set(data, forKey: "Conversations")
    }

    // MARK: - 导出

    func exportConversation() -> String {
        let export = conversations.map { conv -> [String: Any] in
            [
                "title": conv.title,
                "model": conv.modelId,
                "created": ISO8601DateFormatter().string(from: conv.createdAt),
                "messages": conv.messages.map { msg -> [String: Any] in
                    [
                        "role": msg.role.rawValue,
                        "content": msg.content,
                        "time": ISO8601DateFormatter().string(from: msg.timestamp)
                    ]
                }
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return json
    }
}

// MARK: - Markdown 渲染辅助
extension ChatViewModel {

    /// 将 Markdown 转换为 AttributedString
    /// 实际项目建议使用 swift-markdown 或自定义解析器
    func renderMarkdown(_ text: String) -> AttributedString {
        do {
            var attributed = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            ))
            return attributed
        } catch {
            return AttributedString(text)
        }
    }
}
