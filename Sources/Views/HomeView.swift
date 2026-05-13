import SwiftUI

struct HomeView: View {
    @State private var selectedTab: Tab = .chat

    enum Tab: String, CaseIterable {
        case chat = "对话"
        case market = "模型市场"
        case history = "历史记录"
        case settings = "设置"

        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .market: return "square.grid.2x2"
            case .history: return "clock.arrow.circlepath"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem {
                    Label(Tab.chat.rawValue, systemImage: Tab.chat.icon)
                }
                .tag(Tab.chat)

            ModelMarketView()
                .tabItem {
                    Label(Tab.market.rawValue, systemImage: Tab.market.icon)
                }
                .tag(Tab.market)

            HistoryView()
                .tabItem {
                    Label(Tab.history.rawValue, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
            }
            .tag(Tab.settings)
        }
        .tint(.purple)
    }
}

// MARK: - 历史记录视图
struct HistoryView: View {
    @State private var conversations: [Conversation] = []
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    ContentUnavailableView(
                        "暂无历史记录",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("开始对话后会自动保存历史记录")
                    )
                } else {
                    List {
                        ForEach(filteredConversations) { conv in
                            NavigationLink {
                                ChatHistoryDetailView(conversation: conv)
                            } label: {
                                ConversationRowView(conversation: conv)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索历史对话...")
            .navigationTitle("历史记录")
            .toolbar {
                if !conversations.isEmpty {
                    EditButton()
                }
            }
        }
    }

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func deleteConversations(at offsets: IndexSet) {
        conversations.remove(atOffsets: offsets)
    }
}

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)

            Text(conversation.messages.last?.content ?? "空对话")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Text(conversation.modelId)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                Text(conversation.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChatHistoryDetailView: View {
    let conversation: Conversation

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(conversation.messages) { message in
                    MessageBubbleView(message: message)
                }
            }
            .padding()
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HomeView()
}
