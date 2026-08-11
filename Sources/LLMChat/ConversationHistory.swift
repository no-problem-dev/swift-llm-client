import Foundation
import LLMClient

// MARK: - ConversationHistory

/// An actor holding the messages and the running token total of one conversation.
///
/// The ready-made implementation of the history protocol. Being an actor, it takes appends from
/// several tasks without tearing the array — a background turn and a UI action can both write. The
/// price is that every read is an `await`: the array `getMessages()` hands back is a copy taken at
/// that instant, and another task may append to the history before the request built from that
/// copy is even sent.
///
/// It holds messages, not provider state, so the same history can be continued against a different
/// provider or model partway through.
///
/// ## Example
///
/// ```swift
/// // Create a history.
/// let history = ConversationHistory()
///
/// // Subscribe to the events, if you want them.
/// Task {
///     for await event in history.eventStream {
///         switch event {
///         case .userMessage(let msg):
///             print("User: \(msg.content)")
///         case .assistantMessage(let msg):
///             print("Assistant: \(msg.content)")
///         case .toolCallMessage(let msg):
///             print("Tool call: \(msg.content)")
///         case .toolResultMessage(let msg):
///             print("Tool result: \(msg.content)")
///         case .usageUpdated(let usage):
///             print("Total tokens: \(usage.totalTokens)")
///         case .cleared:
///             print("History cleared")
///         case .error(let error):
///             print("Error: \(error)")
///         }
///     }
/// }
///
/// // Run a turn.
/// let result: CityInfo = try await client.chat(
///     "What is the capital of Japan?",
///     history: history,
///     model: .sonnet
/// )
///
/// // Inspect the state.
/// print(await history.turnCount)  // 1
/// print(await history.getTotalUsage().totalTokens)  // Tokens used so far
/// ```
///
/// ## Starting from an existing history
///
/// ```swift
/// let existingMessages: [LLMMessage] = [
///     .user("Hello"),
///     .assistant("Hello! How can I help?")
/// ]
/// let history = ConversationHistory(messages: existingMessages)
/// ```
public actor ConversationHistory: ConversationHistoryProtocol {
    // MARK: - Properties

    private var messages: [LLMMessage]

    /// Running total, carrying input and output counts only.
    private var totalUsage: TokenUsage

    /// User messages that were not tool results.
    private var userTurnCount: Int

    /// Set when a tool call or tool result is appended, and cleared by the next read.
    private var needsSanitization: Bool = false

    /// The change feed for this history, with one consumer and no buffer limit.
    ///
    /// A subscriber that starts late still receives everything emitted before it, and a history
    /// nobody subscribes to keeps every event it has ever emitted. The stream is closed when the
    /// history is deallocated.
    public nonisolated let eventStream: AsyncStream<ConversationEvent>

    private let continuation: AsyncStream<ConversationEvent>.Continuation

    // MARK: - Initialization

    /// Creates an empty conversation history.
    public init() {
        self.messages = []
        self.totalUsage = .zero
        self.userTurnCount = 0
        (self.eventStream, self.continuation) = AsyncStream.makeStream(of: ConversationEvent.self)
    }

    /// Resumes a conversation from messages that were saved or built elsewhere.
    ///
    /// The turn count is recomputed from the messages, but the running token total starts at zero:
    /// what the restored turns cost is not recoverable from the messages themselves. Use the
    /// initializer that also takes a usage to keep a cost display continuous across a restore.
    ///
    /// - Parameter messages: The conversation to start from, oldest first.
    public init(messages: [LLMMessage]) {
        self.messages = messages
        self.totalUsage = .zero
        // Derive the turn count from the messages handed in.
        self.userTurnCount = messages.filter { !$0.hasToolResult && $0.role == .user }.count
        (self.eventStream, self.continuation) = AsyncStream.makeStream(of: ConversationEvent.self)
    }

    /// Resumes a conversation along with what it has already cost.
    ///
    /// - Parameters:
    ///   - messages: The conversation to start from, oldest first.
    ///   - totalUsage: The tokens the restored turns already consumed.
    public init(messages: [LLMMessage], totalUsage: TokenUsage) {
        self.messages = messages
        self.totalUsage = totalUsage
        // Derive the turn count from the messages handed in.
        self.userTurnCount = messages.filter { !$0.hasToolResult && $0.role == .user }.count
        (self.eventStream, self.continuation) = AsyncStream.makeStream(of: ConversationEvent.self)
    }

    // MARK: - ConversationHistoryProtocol

    /// Returns the conversation, repairing unanswered tool calls on the way out.
    ///
    /// Reading is not purely a read: when a tool call or tool result has been appended since the
    /// last read, the stored array is first passed through `sanitizeOrphanedToolUses()`, which
    /// answers any unanswered call with a synthetic failure result so that providers do not reject
    /// the request. That rewrite is kept, so the model sees it on every later turn as well.
    public func getMessages() -> [LLMMessage] {
        if needsSanitization {
            messages.sanitizeOrphanedToolUses()
            needsSanitization = false
        }
        return messages
    }

    public func getTotalUsage() -> TokenUsage {
        totalUsage
    }

    public var turnCount: Int {
        userTurnCount
    }

    public func append(_ message: LLMMessage) {
        messages.append(message)

        // Emit the matching event, and count the user turns.
        let event: ConversationEvent
        if message.hasToolResult {
            event = .toolResultMessage(message)
            needsSanitization = true
        } else if message.hasToolUse {
            event = .toolCallMessage(message)
            needsSanitization = true
        } else if message.role == .user {
            event = .userMessage(message)
            userTurnCount += 1
        } else {
            event = .assistantMessage(message)
        }
        emit(event)
    }

    /// Adds a turn's usage to the running total.
    ///
    /// Reasoning, cache-read and cache-creation counts are carried into the total alongside the
    /// input and output counts, so a cost display driven from `getTotalUsage()` prices cached input
    /// at the cache rate rather than the full one. The cache tier is the one figure that cannot
    /// survive: every turn may be billed at a different lifetime, so the total carries none.
    public func addUsage(_ usage: TokenUsage) {
        totalUsage = totalUsage.adding(usage)
        emit(.usageUpdated(totalUsage))
    }

    /// Empties the messages and the running token total.
    ///
    /// The turn count is not reset, so it keeps climbing across a clear and describes the life of
    /// the object rather than the conversation now in it. Start a new history instead where the
    /// count has to match what the messages show.
    public func clear() {
        messages = []
        totalUsage = .zero
        emit(.cleared)
    }

    public func emitError(_ error: LLMError) {
        emit(.error(error))
    }

    // MARK: - Cleanup

    deinit {
        continuation.finish()
    }

    // MARK: - Private Methods

    /// Publishes an event, which is never dropped for want of a consumer.
    private func emit(_ event: ConversationEvent) {
        continuation.yield(event)
    }
}
