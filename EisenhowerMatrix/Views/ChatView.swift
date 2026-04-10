import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct ChatView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var messages: [ChatMessage] = [
        ChatMessage(
            text: "Hi! I'm your Eisenhower Matrix assistant. I can help you categorize tasks, review your matrix, or give productivity tips. What would you like to do?",
            isUser: false
        )
    ]
    @State private var inputText = ""
    @State private var isTyping = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                            if isTyping {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: isTyping) { _ in
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }

                // Quick prompts
                if messages.count == 1 {
                    quickPrompts
                }

                inputBar
            }
            .navigationTitle("Chat")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    // MARK: - Quick prompts

    private var quickPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPromptOptions, id: \.self) { prompt in
                    Button(prompt) {
                        sendMessage(prompt)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private let quickPromptOptions = [
        "Review my tasks",
        "Tips for Do quadrant",
        "How to delegate?",
        "What to eliminate?",
        "Productivity tips",
    ]

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask anything…", text: $inputText, axis: .vertical)
                .lineLimit(3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            Button {
                let text = inputText.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return }
                sendMessage(text)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Send

    private func sendMessage(_ text: String) {
        messages.append(ChatMessage(text: text, isUser: true))
        inputText = ""
        isTyping = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isTyping = false
            messages.append(ChatMessage(text: generateReply(to: text), isUser: false))
        }
    }

    // MARK: - Simple reply logic

    private func generateReply(to text: String) -> String {
        let lower = text.lowercased()

        if lower.contains("review") || lower.contains("status") {
            let do4    = taskStore.tasks(for: .doFirst).filter { !$0.isCompleted }.count
            let sched  = taskStore.tasks(for: .schedule).filter { !$0.isCompleted }.count
            let del    = taskStore.tasks(for: .delegate).filter { !$0.isCompleted }.count
            let elim   = taskStore.tasks(for: .eliminate).filter { !$0.isCompleted }.count
            return """
            Here's your current matrix:
            🚀 Do: \(do4) pending tasks
            🔥 Schedule: \(sched) pending tasks
            👥 Delegate: \(del) pending tasks
            🗂️ Eliminate: \(elim) pending tasks

            Focus on your "Do" quadrant first — those are urgent AND important!
            """
        }

        if lower.contains("do ") || lower.contains("urgent") || lower.contains("important") {
            return """
            The **Do** quadrant (🚀) is for tasks that are both Urgent and Important.

            Tips:
            • Tackle these first thing in the morning
            • Keep this list short (under 5 tasks ideally)
            • If you have too many, ask: are all really urgent?
            • Batch similar tasks to reduce context-switching
            """
        }

        if lower.contains("delegate") {
            return """
            The **Delegate** quadrant (👥) is for tasks that are Urgent but Not Important.

            Tips:
            • Identify who can handle each task
            • Provide clear instructions and deadlines
            • Check in periodically but don't micromanage
            • This frees you to focus on what truly matters
            """
        }

        if lower.contains("eliminate") || lower.contains("eliminate") {
            return """
            The **Eliminate** quadrant (🗂️) is for tasks that are Neither Urgent nor Important.

            Tips:
            • Be ruthless — ask "what happens if I don't do this?"
            • Schedule a "clean-up" session once a week
            • Many of these can be automated or simply dropped
            • Social media browsing often belongs here!
            """
        }

        if lower.contains("schedule") || lower.contains("plan") {
            return """
            The **Schedule** quadrant (🔥) is for tasks that are Important but Not Urgent.

            Tips:
            • Block calendar time for these proactively
            • These are often long-term goals — don't neglect them
            • Examples: learning, health, relationships, strategy
            • Eisenhower himself spent most time here!
            """
        }

        if lower.contains("tip") || lower.contains("productiv") {
            let tips = [
                "Review your matrix every morning — it only takes 2 minutes.",
                "Limit your 'Do' quadrant to 3-5 tasks per day for focus.",
                "Saying 'no' is the ultimate Eliminate skill.",
                "Time-block your 'Schedule' tasks or they'll never happen.",
                "The goal is to spend most time in 'Schedule' — planning prevents crises.",
            ]
            return "💡 " + (tips.randomElement() ?? tips[0])
        }

        return """
        I can help you with your Eisenhower Matrix!

        Try asking me:
        • "Review my tasks"
        • "Tips for the Do quadrant"
        • "How to delegate effectively?"
        • "What should I eliminate?"
        • "Give me a productivity tip"
        """
    }
}

// MARK: - Message bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Color.blue : Color(uiColor: .systemBackground))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.05), radius: 2)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing indicator

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animate ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(18)
            .onAppear { animate = true }

            Spacer(minLength: 60)
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(TaskStore())
}
