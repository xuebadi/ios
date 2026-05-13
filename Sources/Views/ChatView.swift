import SwiftUI
import PhotosUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText: String = ""
    @State private var selectedImageData: [Data] = []
    @State private var selectedImageItems: [PhotosPickerItem] = []
    @State private var isRecording: Bool = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isGenerating {
                                ThinkingDotsView()
                                    .padding(.leading, 16)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, viewModel.isGenerating ? 100 : 80)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let lastId = viewModel.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                // 底部输入区域
                VStack(spacing: 0) {
                    // 图片预览
                    if !selectedImageData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedImageData.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: UIImage(data: selectedImageData[index]) ?? UIImage())
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            selectedImageData.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white)
                                                .shadow(radius: 2)
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .background(Color(.systemGray6))
                    }

                    // 模型状态指示
                    HStack {
                        Circle()
                            .fill(viewModel.isGenerating ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)
                        Text(viewModel.isGenerating ? "推理中..." : "本地运行中")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !viewModel.isGenerating {
                            Text("\(viewModel.modelName)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)

                    // 输入框和按钮
                    HStack(alignment: .bottom, spacing: 8) {
                        // 图片按钮
                        PhotosPicker(
                            selection: $selectedImageItems,
                            maxSelectionCount: 9,
                            matching: .images
                        ) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                        }
                        .onChange(of: selectedImageItems) { _, newItems in
                            Task {
                                var newImages: [Data] = []
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self) {
                                        newImages.append(data)
                                    }
                                }
                                selectedImageData = newImages
                            }
                        }

                        // 文本输入
                        TextField("发送消息...", text: $inputText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...6)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .focused($isInputFocused)

                        // 发送/停止按钮
                        Button {
                            if viewModel.isGenerating {
                                viewModel.stopGeneration()
                            } else {
                                sendMessage()
                            }
                        } label: {
                            Group {
                                if viewModel.isGenerating {
                                    Image(systemName: "stop.fill")
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 28))
                                }
                            }
                            .foregroundColor(viewModel.isGenerating ? .red : .accentColor)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData.isEmpty && !viewModel.isGenerating)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("学霸帝AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "trash")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .onAppear {
                viewModel.setup()
            }
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !selectedImageData.isEmpty else { return }

        let content = trimmed
        let images = selectedImageData
        inputText = ""
        selectedImageData = []
        selectedImageItems = []

        Task {
            await viewModel.sendMessage(content: content, imageData: images)
        }
    }
}

// MARK: - 消息气泡
struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                // AI 头像
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text("🤖")
                            .font(.system(size: 14))
                    }
                Spacer(minLength: 0)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // 消息内容
                if let imageData = message.imageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !message.content.isEmpty {
                    if message.isThinking {
                        ThinkingBubbleView(text: message.content)
                    } else {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(message.role == .user ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                message.role == .user
                                    ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : Color(.systemGray5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }

                // 时间戳
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .user {
                Spacer(minLength: 0)
                // 用户头像
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text("👤")
                            .font(.system(size: 14))
                    }
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - 思考动画
struct ThinkingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .opacity(animating ? 0.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
            Text("学霸帝思考中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { animating = true }
    }
}

// MARK: - 思考气泡
struct ThinkingBubbleView: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("🧠 深度思考")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            if isExpanded {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: 260, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ChatView()
}
