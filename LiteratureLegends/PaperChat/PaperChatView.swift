//
//  PaperChatView.swift
//  LiteratureLegends · PaperChat
//
//  "Ask about this…" research analysis from images/Wireframe2.jpeg: message bubbles, a thinking
//  indicator, the question field with a send button, and a "[1] Title (Year)" source footer.
//

import SwiftUI

struct PaperChatView: View {
    @State private var viewModel: PaperChatViewModel
    @FocusState private var isInputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typingMessageID: UUID?
    @State private var revealedText = AttributedString()

    init(
        paper: Paper,
        service: any ChatService = GeminiChatService(),
        persistence: (any ChatPersisting)? = nil
    ) {
        _viewModel = State(
            initialValue: PaperChatViewModel(
                paper: paper,
                service: service,
                persistence: persistence
            )
        )
    }

    init(viewModel: PaperChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        introCard
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message,
                                          revealedText: message.id == typingMessageID ? revealedText : nil)
                                .id(message.id)
                        }
                        if viewModel.isSending {
                            ThinkingBubble().id("thinking")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { previous, current in
                    typingMessageID = nil
                    if current > previous {
                        if !reduceMotion, let reply = viewModel.messages.last, reply.role == .assistant {
                            revealedText = AttributedString()
                            typingMessageID = reply.id
                        }
                    }
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isSending) { scrollToBottom(proxy) }
            }

            Divider()
            sourceFooter
            inputBar
        }
        .task(id: typingMessageID) {
            guard let typingMessageID, let reply = viewModel.messages.last, reply.id == typingMessageID else { return }
            await reveal(reply)
        }
        .onChange(of: reduceMotion) { if reduceMotion { typingMessageID = nil } }
        .onDisappear { typingMessageID = nil }
        .navigationTitle("Research Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func reveal(_ reply: ChatMessage) async {
        // Parse once so emphasis and citations stay intact as the text appears.
        let formatted = MessageBubble.render(reply.text)
        let characters = formatted.characters
        let step = max(2, (characters.count + 119) / 120)
        var end = characters.startIndex
        while end < characters.endIndex {
            guard !Task.isCancelled, typingMessageID == reply.id else { return }
            end = characters.index(end, offsetBy: step, limitedBy: characters.endIndex) ?? characters.endIndex
            revealedText = AttributedString(formatted[..<end])
            if end < characters.endIndex {
                do { try await Task.sleep(for: .milliseconds(32)) } catch { return }
            }
        }
        typingMessageID = nil
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .default) {
            if viewModel.isSending {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI response", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text("Ask a question about “\(viewModel.paper.title)”. Answers use only this paper's title, details, and abstract, and cite it as [1].")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var sourceFooter: some View {
        HStack(spacing: 6) {
            Text("Sources")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let url = viewModel.paper.openURL {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text(viewModel.sourceLabel).lineLimit(1)
                        Image(systemName: "arrow.up.right.square")
                    }
                }
                .font(.caption)
                .accessibilityHint("Opens the paper in Safari")
            } else {
                Text(viewModel.sourceLabel)
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about this…", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
                    .disabled(!viewModel.isConfigured || viewModel.hasReachedDailyLimit)

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Send question")
            }

            HStack {
                Text(viewModel.hasReachedDailyLimit
                     ? "Daily limit reached. Come back tomorrow."
                     : "\(viewModel.remainingToday) questions left today")
                Spacer()
                if viewModel.trimmedDraft.count > PaperChatViewModel.maxQuestionLength - 200 {
                    Text("\(viewModel.trimmedDraft.count)/\(PaperChatViewModel.maxQuestionLength)")
                        .foregroundStyle(viewModel.isDraftTooLong ? .red : .secondary)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let revealedText: AttributedString?

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            ZStack(alignment: .topLeading) {
                // Reserve the completed reply's size so the bubble doesn't reflow while text is revealed.
                Text(Self.render(message.text))
                    .hidden()
                Text(revealedText ?? Self.render(message.text))
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .background(isUser ? AnyShapeStyle(.tint) : AnyShapeStyle(.background.secondary),
                        in: RoundedRectangle(cornerRadius: 18))
            if !isUser { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "You: \(message.text)" : "Assistant: \(message.text)")
    }

    /// Renders simple Markdown (bold, italics) from the model; falls back to plain text.
    static func render(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

private struct ThinkingBubble: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Thinking…").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityLabel("Assistant is thinking")
    }
}

#Preview("Conversation") {
    NavigationStack {
        PaperChatView(paper: MockPaperSearchService.sample, service: MockChatService())
    }
}

#Preview("Missing key") {
    NavigationStack {
        PaperChatView(paper: MockPaperSearchService.sample, service: MockChatService(isConfigured: false))
    }
}

#Preview("Quota error") {
    NavigationStack {
        PaperChatView(paper: MockPaperSearchService.sample, service: MockChatService(behavior: .failure(.quotaExceeded)))
    }
}
