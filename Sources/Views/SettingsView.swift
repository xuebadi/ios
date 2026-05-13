import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.load()
    @State private var showingResetAlert = false

    var body: some View {
        Form {
            // MARK: 模型选择
            Section {
                NavigationLink {
                    ModelListView(selectedModelId: $settings.selectedModelId)
                } label: {
                    HStack {
                        Label("当前模型", systemImage: "cpu")
                        Spacer()
                        Text(settings.selectedModelId)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text("模型")
            }

            // MARK: 推理设置
            Section {
                Picker("后端", selection: $settings.backendType) {
                    ForEach(AppSettings.BackendType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Stepper("线程数: \(settings.threadCount)", value: $settings.threadCount, in: 1...16)

                Picker("精度", selection: $settings.precision) {
                    ForEach(AppSettings.Precision.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }

                Toggle("启用内存映射 (MMap)", isOn: $settings.enableMMap)
            } header: {
                Text("推理设置")
            } footer: {
                Text("Metal GPU 在支持的设备上可大幅加速推理。线程数建议设置为 CPU 核心数的一半。")
            }

            // MARK: 生成参数
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.2f", settings.generationConfig.temperature))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.generationConfig.temperature, in: 0.1...2.0)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Top-P")
                        Spacer()
                        Text(String(format: "%.2f", settings.generationConfig.topP))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.generationConfig.topP, in: 0.1...1.0)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Top-K")
                        Spacer()
                        Text("\(settings.generationConfig.topK)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.generationConfig.topK) },
                        set: { settings.generationConfig.topK = Int($0) }
                    ), in: 1...100, step: 1)
                }

                Stepper("最大生成长度: \(settings.generationConfig.maxNewTokens)",
                        value: $settings.generationConfig.maxNewTokens, in: 256...8192, step: 256)
            } header: {
                Text("生成参数")
            } footer: {
                Text("Temperature 控制随机性，值越高越有创意越不稳定。Top-P 和 Top-K 控制词汇选择的保守程度。")
            }

            // MARK: 功能开关
            Section {
                Toggle("Markdown 渲染", isOn: $settings.enableMarkdown)
                Toggle("深度思考模式", isOn: $settings.enableThinking)
                Toggle("音频输出 (Omni模型)", isOn: $settings.audioOutput)
            } header: {
                Text("功能")
            }

            // MARK: 关于
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("MNN 版本")
                    Spacer()
                    Text("2026.03")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("设备内存")
                    Spacer()
                    Text(DeviceInfo.shared.formattedTotalMemory)
                        .foregroundColor(.secondary)
                }

                Button("恢复默认设置", role: .destructive) {
                    showingResetAlert = true
                }
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.selectedModelId) { _, _ in save() }
        .onChange(of: settings.backendType) { _, _ in save() }
        .onChange(of: settings.threadCount) { _, _ in save() }
        .onChange(of: settings.precision) { _, _ in save() }
        .onChange(of: settings.enableMMap) { _, _ in save() }
        .onChange(of: settings.enableMarkdown) { _, _ in save() }
        .onChange(of: settings.enableThinking) { _, _ in save() }
        .onChange(of: settings.audioOutput) { _, _ in save() }
        .alert("恢复默认设置?", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                settings = AppSettings()
                save()
            }
        }
    }

    private func save() {
        settings.save()
    }
}

// MARK: - 模型列表视图
struct ModelListView: View {
    @Binding var selectedModelId: String
    @State private var models: [ModelInfo] = ModelInfo.defaultModels()
    @State private var searchText = ""
    @State private var selectedCategory: ModelInfo.ModelCategory?

    var filteredModels: [ModelInfo] {
        models.filter { model in
            let matchCategory = selectedCategory == nil || model.category == selectedCategory
            let matchSearch = searchText.isEmpty ||
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchCategory && matchSearch
        }
    }

    var body: some View {
        List {
            // 分类筛选
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(title: "全部", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(ModelInfo.ModelCategory.allCases, id: \.self) { cat in
                            CategoryChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                                selectedCategory = cat
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // 模型列表
            ForEach(filteredModels) { model in
                ModelRowView(
                    model: model,
                    isSelected: model.id == selectedModelId,
                    onSelect: {
                        selectedModelId = model.id
                    }
                )
            }
        }
        .searchable(text: $searchText, prompt: "搜索模型...")
        .navigationTitle("选择模型")
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ModelRowView: View {
    let model: ModelInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 模型图标
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(categoryEmoji)
                            .font(.title2)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(model.parameters) · \(model.quantization)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(model.size)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(model.category.rawValue)
                            .font(.caption2)
                            .foregroundColor(categoryColor)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else if model.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch model.category {
        case .text: return .blue
        case .vision: return .purple
        case .audio: return .orange
        case .omni: return .green
        case .local: return .gray
        }
    }

    private var categoryEmoji: String {
        switch model.category {
        case .text: return "📝"
        case .vision: return "👁️"
        case .audio: return "🎙️"
        case .omni: return "🌟"
        case .local: return "💾"
        }
    }
}

// MARK: - AppSettings 扩展
extension AppSettings {
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "AppSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "AppSettings")
        }
    }
}

// MARK: - 设备信息
class DeviceInfo {
    static let shared = DeviceInfo()

    var totalMemory: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    var formattedTotalMemory: String {
        let gb = Double(totalMemory) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - 默认模型列表
extension ModelInfo {
    static func defaultModels() -> [ModelInfo] {
        [
            // 全模态 (Qwen2.5-VL 系列)
            ModelInfo(
                id: "Qwen2.5-VL-3B-Instruct",
                name: "Qwen2.5-VL-3B-Instruct",
                size: "~3.6 GB",
                parameters: "3B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .omni,
                tags: ["Qwen", "多模态", "视觉", "中文"],
                isDownloaded: false
            ),
            ModelInfo(
                id: "Qwen2.5-VL-7B-Instruct",
                name: "Qwen2.5-VL-7B-Instruct",
                size: "~8.2 GB",
                parameters: "7B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .omni,
                tags: ["Qwen", "多模态", "视觉", "高性能"],
                isDownloaded: false
            ),
            // 视觉模型
            ModelInfo(
                id: "Qwen2-VL-2B-Instruct",
                name: "Qwen2-VL-2B-Instruct",
                size: "~2.4 GB",
                parameters: "2B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .vision,
                tags: ["Qwen", "视觉", "轻量"],
                isDownloaded: false
            ),
            // 文本模型
            ModelInfo(
                id: "Qwen2.5-0.5B-Instruct",
                name: "Qwen2.5-0.5B-Instruct",
                size: "~600 MB",
                parameters: "0.5B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .text,
                tags: ["Qwen", "文本", "超轻量", "iPhone"],
                isDownloaded: false
            ),
            ModelInfo(
                id: "Qwen2.5-1.5B-Instruct",
                name: "Qwen2.5-1.5B-Instruct",
                size: "~1.8 GB",
                parameters: "1.5B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .text,
                tags: ["Qwen", "文本", "轻量"],
                isDownloaded: false
            ),
            ModelInfo(
                id: "Qwen2.5-3B-Instruct",
                name: "Qwen2.5-3B-Instruct",
                size: "~3.5 GB",
                parameters: "3B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .text,
                tags: ["Qwen", "文本", "均衡"],
                isDownloaded: false
            ),
            ModelInfo(
                id: "Qwen2.5-7B-Instruct",
                name: "Qwen2.5-7B-Instruct",
                size: "~8.1 GB",
                parameters: "7B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .text,
                tags: ["Qwen", "文本", "高性能"],
                isDownloaded: false
            ),
            // DeepSeek
            ModelInfo(
                id: "DeepSeek-R1-Distill-Qwen-1.5B",
                name: "DeepSeek-R1-Distill-Qwen-1.5B",
                size: "~1.8 GB",
                parameters: "1.5B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .text,
                tags: ["DeepSeek", "推理", "思考"],
                isDownloaded: false
            ),
            ModelInfo(
                id: "DeepSeek-R1-Distill-Qwen-7B",
                name: "DeepSeek-R1-Distill-Qwen-7B",
                size: "~8.2 GB",
                parameters: "7B",
                quantization: "INT4",
                downloadURL: "https://modelscope.cn/organization/MNN",
                category: .text,
                tags: ["DeepSeek", "推理", "高性能"],
                isDownloaded: false
            )
        ]
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
