import Foundation
import UIKit

// MARK: - MNN LLM 服务 (本地多模态推理引擎)
/// 核心服务：封装 MNN C++ LLM 推理引擎的所有功能
/// 支持：文本生成、视觉理解、语音合成 (Omni模型)
/// 架构：SwiftUI → ViewModel → MNNService → libMNN.dylib
final class MNNService: NSObject, ObservableObject {

    // MARK: - 单例
    static let shared = MNNService()

    // MARK: - 发布属性 (UI 绑定)
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var currentModelId: String = ""
    @Published private(set) var vRAMUsage: UInt64 = 0
    @Published private(set) var tokenSpeed: Double = 0  // tokens/s

    // MARK: - 内部状态
    private var currentSession: UnsafeMutableRawPointer?
    private var modelConfig: ModelConfig?
    private var generationConfig: GenerationConfig = .default
    private var cancellables: Set<AnyCancellable> = []
    private var currentTask: Task<Void, Never>?
    private var streamBuffer: String = ""
    private var tokenCount: Int = 0
    private var lastTokenTime: Date = Date()

    // MARK: - 回调
    var onTokenReceived: ((String) -> Void)?
    var onThinkingReceived: ((String) -> Void)?
    var onComplete: ((Bool) -> Void)?

    // MARK: - 初始化

    /// 初始化 MNN 推理引擎
    /// - Parameters:
    ///   - modelPath: MNN 模型文件夹路径 (含 llm.mnn, llm.mnn.weight, tokenizer.mtok, config.json)
    ///   - config: 生成配置
    ///   - settings: 应用设置
    /// - Returns: 是否初始化成功
    @discardableResult
    func initialize(
        modelPath: String,
        config: GenerationConfig = .default,
        settings: AppSettings = .load()
    ) async -> Bool {
        guard !isInitialized else {
            print("[MNN] Already initialized with model: \(currentModelId)")
            return true
        }

        print("[MNN] Initializing with model at: \(modelPath)")
        print("[MNN] Backend: \(settings.backendType.rawValue), Threads: \(settings.threadCount)")
        print("[MNN] Precision: \(settings.precision.displayName)")

        // 构建 config.json (MNN LLM 运行时配置)
        let runtimeConfig = buildRuntimeConfig(settings: settings)

        do {
            // 模拟初始化过程 (实际项目中调用 libMNN.dylib)
            try await simulateModelLoad(modelPath: modelPath, config: runtimeConfig)

            currentModelId = (modelPath as NSString).lastPathComponent
            generationConfig = config
            isInitialized = true

            print("[MNN] ✅ Initialized successfully: \(currentModelId)")
            return true
        } catch {
            print("[MNN] ❌ Initialization failed: \(error)")
            return false
        }
    }

    /// 从模型 ID 查找本地路径并初始化
    func initializeWithModelId(_ modelId: String) async -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent("Models/\(modelId)")

        if FileManager.default.fileExists(atPath: modelPath.path) {
            return await initialize(modelPath: modelPath.path)
        } else {
            // 使用内置默认模型 (App Bundle)
            let bundlePath = Bundle.main.resourcePath ?? ""
            let bundledModelPath = (bundlePath as NSString).appendingPathComponent("LocalModel/\(modelId)")
            if FileManager.default.fileExists(atPath: bundledModelPath) {
                return await initialize(modelPath: bundledModelPath)
            }
        }

        print("[MNN] ⚠️ Model not found: \(modelId), using demo mode")
        return await initializeWithDemoModel()
    }

    /// Demo 模式：无需真实模型，提供模拟推理能力
    private func initializeWithDemoModel() async -> Bool {
        currentModelId = "Demo Mode"
        generationConfig = .default
        isInitialized = true
        print("[MNN] 🧪 Running in Demo Mode")
        return true
    }

    // MARK: - 推理

    /// 发送消息并流式获取响应
    /// - Parameters:
    ///   - content: 文本内容
    ///   - imageData: 可选的图片数据数组
    ///   - enableThinking: 是否启用深度思考
    func generate(
        content: String,
        imageData: [Data] = [],
        enableThinking: Bool = false
    ) async {
        guard isInitialized else {
            print("[MNN] Not initialized, cannot generate")
            return
        }

        isGenerating = true
        tokenCount = 0
        lastTokenTime = Date()
        streamBuffer = ""

        print("[MNN] Generating for: \(content.prefix(50))...")
        print("[MNN] Image count: \(imageData.count), Thinking: \(enableThinking)")

        // 构建带标签的 prompt
        var prompt = content
        for _ in imageData {
            prompt = "\(ChatContextTag.image)\n\(prompt)"
        }

        currentTask = Task {
            do {
                if currentModelId == "Demo Mode" {
                    // Demo 模式：模拟流式输出
                    try await demoStreamResponse(prompt: prompt, thinking: enableThinking)
                } else {
                    // 真实推理：通过 C++ 桥接调用 MNN LLM
                    try await realStreamResponse(prompt: prompt, thinking: enableThinking)
                }

                await MainActor.run {
                    self.isGenerating = false
                    self.onComplete?(true)
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.onComplete?(false)
                }
            }
        }
    }

    /// 停止当前生成
    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
        print("[MNN] Generation stopped by user")
    }

    // MARK: - Demo 模式模拟

    private func demoStreamResponse(prompt: String, thinking: Bool) async throws {
        // 模拟 Qwen 风格的回复
        let demoResponses = [
            "你好！我是学霸帝AI，基于 Qwen2.5-VL-3B 模型运行在本地设备上。🧠\n\n我可以帮你：\n📸 **看图分析** - 识别图片内容并回答问题\n📝 **写作助手** - 帮你写文章、总结、翻译\n📚 **学习辅导** - 解答数学、理科等学科问题\n💡 **创意生成** - 提供创意点子和解决方案\n\n请上传图片或直接提问吧！",

            "根据你的问题，我来为你分析：\n\n**核心要点：**\n1. 这个问题涉及到基础知识的核心概念\n2. 需要分步骤理解每个环节\n3. 建议结合实际案例加深理解\n\n**详细解答：**\n首先，我们需要明确问题的前提条件...（此处由本地AI实时生成）",

            "🖼️ 图片分析结果：\n\n**主要元素：** 包含文字和图形信息\n**内容识别：** 初步判断为概念图或流程图\n**建议：** 如需更精确的分析，请提供更高清的图片或具体说明需求\n\n---\n\n*以上内容由 **学霸帝AI** 本地模型生成，完全离线运行，保护隐私。*"
        ]

        let response = demoResponses.randomElement() ?? demoResponses[0]
        let thinkingText = thinking ? "让我仔细思考一下这个问题...\n\n首先，我需要理解题目的核心要求：\n1. 识别关键信息\n2. 建立知识联系\n3. 验证推理过程\n\n经过分析，我认为关键在于..." : nil

        // 流式输出思考过程
        if let thinking = thinkingText {
            for char in thinking {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 20_000_000) // 20ms
                streamBuffer.append(char)
                if char == "\n" || streamBuffer.count % 15 == 0 {
                    await MainActor.run {
                        self.onThinkingReceived?(self.streamBuffer)
                    }
                }
            }
        }

        // 流式输出回复
        for char in response {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 30_000_000) // 30ms/token

            streamBuffer.append(char)
            tokenCount += 1

            // 更新速度
            let elapsed = Date().timeIntervalSince(lastTokenTime)
            if elapsed > 0.5 {
                tokenSpeed = Double(tokenCount) / elapsed
                tokenCount = 0
                lastTokenTime = Date()
            }

            // 回调通知
            await MainActor.run {
                self.onTokenReceived?(String(char))
            }
        }
    }

    // MARK: - 真实推理 (C++ 桥接)

    /// 真实推理：调用 MNN LLM C++ 引擎
    /// 实际项目中通过 MNN-Bridging-Header.h 暴露 C++ 接口
    private func realStreamResponse(prompt: String, thinking: Bool) async throws {
        // =========================================================
        // 真实实现说明 (实际项目中取消注释并配置 C++ 桥接)
        // =========================================================
        //
        // // 1. 准备 MNN Session
        // guard let session = currentSession else { return }
        //
        // // 2. Tokenize
        // let inputTokens = MNNTokenizer_encode(prompt)
        //
        // // 3. 配置推理参数
        // var params = MNNInferenceParams()
        // params.max_new_tokens = Int32(generationConfig.maxNewTokens)
        // params.temperature = Float(generationConfig.temperature)
        // params.top_p = Float(generationConfig.topP)
        // params.top_k = Int32(generationConfig.topK)
        // params.repeat_penalty = Float(generationConfig.repeatPenalty)
        // params.stream_interval = Int32(generationConfig.streamInterval)
        //
        // // 4. 创建推理流
        // let stream = MNNInferenceStream_create(session, &params)
        //
        // // 5. 流式推理循环
        // while MNNInferenceStream_hasNext(stream) {
        //     try Task.checkCancellation()
        //
        //     let token = MNNInferenceStream_next(stream)
        //     let text = MNNTokenizer_decode(token)
        //
        //     await MainActor.run {
        //         self.onTokenReceived?(text)
        //     }
        //
        //     // 检测思考模式
        //     if thinking && text.contains("<｜") {
        //         // 进入/退出思考模式
        //         await MainActor.run {
        //             self.onThinkingReceived?(self.thinkingBuffer)
        //             self.thinkingBuffer = ""
        //         }
        //     }
        //
        //     try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / 20)) // ~20 tok/s
        // }
        //
        // MNNInferenceStream_destroy(stream)
        // =========================================================

        // 当前使用 Demo 模拟 (真实项目请实现上述 C++ 桥接)
        try await demoStreamResponse(prompt: prompt, thinking: thinking)
    }

    // MARK: - 工具方法

    /// 构建 MNN LLM 运行时配置
    private func buildRuntimeConfig(settings: AppSettings) -> [String: Any] {
        let backend: String = {
            switch settings.backendType {
            case .cpu: return "cpu"
            case .metal: return "metal"
            }
        }()

        let precision: String = {
            switch settings.precision {
            case .low: return "low"      // FP16 量化
            case .normal: return "normal" // INT8 量化
            case .high: return "high"     // FP32
            }
        }()

        return [
            "backend_type": backend,
            "thread_num": settings.threadCount,
            "precision": precision,
            "use_mmap": settings.enableMMap,
            "max_new_tokens": generationConfig.maxNewTokens,
            "temperature": generationConfig.temperature,
            "topP": generationConfig.topP,
            "top_k": generationConfig.topK,
            "repeat_penalty": generationConfig.repeatPenalty,
            "sampler_type": "mixed",
            "reuse_kv": true,
            "chunk": 512,
            "vision": true,
            "audio": settings.audioOutput
        ] as [String: Any]
    }

    /// 导出当前配置为 JSON 文件
    func exportConfig() -> String? {
        let settings = AppSettings.load()
        let config = buildRuntimeConfig(settings: settings)

        guard let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return json
    }

    /// 获取内存使用情况
    func getMemoryUsage() -> UInt64 {
        // 真实项目：从 MNN 运行时获取
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    /// 卸载模型并释放内存
    func unloadModel() {
        stopGeneration()
        currentSession = nil
        modelConfig = nil
        isInitialized = false
        currentModelId = ""
        print("[MNN] Model unloaded, memory freed")
    }
}

// MARK: - 模型配置
struct ModelConfig {
    let modelPath: String
    let configPath: String
    let tokenizerPath: String
    let backendType: String
    let threadCount: Int
    let precision: String
    let useMMap: Bool
}

// MARK: - 推理错误
enum MNNError: LocalizedError {
    case notInitialized
    case modelNotFound(String)
    case inferenceFailed(String)
    case outOfMemory
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "MNN 引擎未初始化"
        case .modelNotFound(let path):
            return "模型文件未找到: \(path)"
        case .inferenceFailed(let reason):
            return "推理失败: \(reason)"
        case .outOfMemory:
            return "内存不足，请选择更小的模型或减少线程数"
        case .cancelled:
            return "推理已被用户取消"
        }
    }
}
