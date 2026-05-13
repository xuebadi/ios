import SwiftUI

struct ModelMarketView: View {
    @State private var models: [ModelInfo] = ModelInfo.defaultModels()
    @State private var searchText = ""
    @State private var selectedCategory: ModelInfo.ModelCategory?
    @State private var downloadingIds: Set<String> = {}
    @State private var downloadProgress: [String: Double] = [:]

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
            // MARK: 已下载模型
            let downloadedModels = filteredModels.filter { $0.isDownloaded }
            if !downloadedModels.isEmpty {
                Section("已下载") {
                    ForEach(downloadedModels) { model in
                        DownloadedModelRow(model: model)
                    }
                }
            }

            // MARK: 模型市场
            Section("模型市场") {
                ForEach(filteredModels.filter { !$0.isDownloaded }) { model in
                    DownloadableModelRow(
                        model: model,
                        isDownloading: downloadingIds.contains(model.id),
                        progress: downloadProgress[model.id] ?? 0,
                        onDownload: { startDownload(model) },
                        onCancel: { cancelDownload(model) }
                    )
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索模型...")
        .navigationTitle("模型市场")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("全部") { selectedCategory = nil }
                    Divider()
                    ForEach(ModelInfo.ModelCategory.allCases, id: \.self) { cat in
                        Button(cat.rawValue) { selectedCategory = cat }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private func startDownload(_ model: ModelInfo) {
        downloadingIds.insert(model.id)
        downloadProgress[model.id] = 0

        // 模拟下载进度
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard downloadingIds.contains(model.id) else {
                timer.invalidate()
                return
            }
            let current = downloadProgress[model.id] ?? 0
            if current >= 1.0 {
                timer.invalidate()
                downloadingIds.remove(model.id)
                downloadProgress.removeValue(forKey: model.id)
                if let index = models.firstIndex(where: { $0.id == model.id }) {
                    models[index].isDownloaded = true
                }
            } else {
                downloadProgress[model.id] = current + 0.02
            }
        }
    }

    private func cancelDownload(_ model: ModelInfo) {
        downloadingIds.remove(model.id)
        downloadProgress.removeValue(forKey: model.id)
    }
}

// MARK: - 已下载模型行
struct DownloadedModelRow: View {
    let model: ModelInfo

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(categoryEmoji)
                        .font(.title3)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.subheadline.bold())
                HStack(spacing: 4) {
                    Text(model.parameters)
                    Text("·")
                    Text(model.quantization)
                    Text("·")
                    Text(model.size)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                // 删除操作
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
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

// MARK: - 可下载模型行
struct DownloadableModelRow: View {
    let model: ModelInfo
    let isDownloading: Bool
    let progress: Double
    let onDownload: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(categoryEmoji)
                            .font(.title3)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.subheadline.bold())
                    HStack(spacing: 4) {
                        Text(model.parameters)
                        Text("·")
                        Text(model.quantization)
                        Text("·")
                        Text(model.size)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    Text(model.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(categoryColor)
                }

                Spacer()

                if isDownloading {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                } else {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                    }
                }
            }

            if isDownloading {
                ProgressView(value: progress)
                    .tint(.accentColor)
                    .padding(.horizontal, 4)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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

#Preview {
    NavigationStack {
        ModelMarketView()
    }
}
