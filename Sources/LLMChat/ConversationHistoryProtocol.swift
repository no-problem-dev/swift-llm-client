import Foundation
import LLMClient

// MARK: - ConversationHistoryProtocol

/// The store a multi-turn conversation is kept in: its messages, its token total, and its changes.
///
/// Three responsibilities: hold and return the messages, accumulate what the turns have cost, and
/// announce every change on an event stream. What it holds are messages rather than provider
/// state, so a conversation can move between models and providers between turns.
///
/// ## Example
///
/// ```swift
/// let history = ConversationHistory()
///
/// // Open the conversation with Claude.
/// let claude = AnthropicClient(apiKey: "...")
/// let result1: CityInfo = try await claude.chat(
///     "What is the capital of Japan?",
///     history: history,
///     model: .sonnet
/// )
///
/// // Continue the same history with GPT.
/// let openai = OpenAIClient(apiKey: "...")
/// let result2: PopulationInfo = try await openai.chat(
///     "What is that city's population?",
///     history: history,
///     model: .gpt4o
/// )
/// ```
///
/// ## Writing your own
///
/// Implement it where the ready-made history is not enough — one that persists to a store or a
/// file, one that summarises older turns to keep the prompt inside the context window, or one
/// that caps how many messages are kept. Dropping or rewriting messages is exactly where a
/// conversation is at risk of losing a tool call and its result as a pair, which providers reject.
///
/// ## Concurrency
///
/// The protocol requires an actor, so every implementation serialises its own state and appends
/// from different tasks cannot tear it. What that does not buy is a stable view across an await:
/// the message array is a copy taken at the moment of the call, and it may already be out of date
/// by the time a request built from it is sent.
public protocol ConversationHistoryProtocol: Actor, Sendable {
    // MARK: - State Access

    /// Returns the conversation so far, oldest first, ready to be sent as a request.
    ///
    /// An implementation may repair the array before returning it — the supplied history answers
    /// unanswered tool calls here — so treat this as the point at which the conversation is made
    /// sendable, not as a plain accessor.
    func getMessages() -> [LLMMessage]

    /// Returns what every request against this history has consumed in total.
    func getTotalUsage() -> TokenUsage

    /// The number of turns the user has taken.
    ///
    /// The supplied history counts user messages that are not tool results, so a turn in which the
    /// model called five tools still counts as one. It is not reset by `clear()`.
    var turnCount: Int { get }

    // MARK: - State Mutation

    /// Appends a message and announces it on the event stream.
    ///
    /// Which event is emitted follows the content, not the role: a message carrying tool calls or
    /// tool results is announced as such rather than as an assistant or user message.
    ///
    /// - Parameter message: The message to append.
    func append(_ message: LLMMessage)

    /// Adds one request's token usage to the running total and announces the new total.
    ///
    /// - Parameter usage: The usage reported for a single request, not a total.
    func addUsage(_ usage: TokenUsage)

    /// Discards the messages and the running token total, then announces the clear.
    func clear()

    /// Announces a failed request on the event stream.
    ///
    /// For observers only. The failing call still throws, so this neither swallows the error nor
    /// substitutes for handling it.
    ///
    /// - Parameter error: The error that was raised.
    func emitError(_ error: LLMError)

    // MARK: - Event Stream

    /// Every change to this history, as an asynchronous stream.
    ///
    /// Nonisolated, so a view can hold it without awaiting the actor. One stream means one
    /// consumer: two tasks iterating it share the events out between them instead of each seeing
    /// all of them, so fan out to several observers yourself rather than iterating twice.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Task {
    ///     for await event in history.eventStream {
    ///         switch event {
    ///         case .userMessage(let msg):
    ///             updateUI(msg)
    ///         case .assistantMessage(let msg):
    ///             updateUI(msg)
    ///         case .toolCallMessage(let msg):
    ///             updateUI(msg)
    ///         case .toolResultMessage(let msg):
    ///             updateUI(msg)
    ///         case .usageUpdated(let usage):
    ///             updateTokenCounter(usage)
    ///         case .cleared:
    ///             resetUI()
    ///         case .error(let error):
    ///             showError(error)
    ///         }
    ///     }
    /// }
    /// ```
    nonisolated var eventStream: AsyncStream<ConversationEvent> { get }
}
