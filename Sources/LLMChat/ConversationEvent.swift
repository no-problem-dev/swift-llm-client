import Foundation
import LLMClient

// MARK: - ConversationEvent

/// Something that happened to a conversation history, delivered on its event stream.
///
/// The stream a history publishes is a plain asynchronous stream, which means one consumer: two
/// tasks iterating the same history split the events between them rather than each receiving all
/// of them. Nothing is lost by subscribing late, though — the stream buffers without limit, so
/// events emitted before anyone iterates arrive as soon as the first consumer starts.
///
/// A message event carries the message that was appended; the enclosing history is not attached,
/// so read the history itself when the full conversation is needed.
///
/// ## Example
///
/// ```swift
/// let history = ConversationHistory()
///
/// // Subscribe to the events.
/// Task {
///     for await event in history.eventStream {
///         switch event {
///         case .userMessage(let message):
///             print("User: \(message.content)")
///         case .assistantMessage(let message):
///             print("Assistant: \(message.content)")
///         case .toolCallMessage(let message):
///             print("Tool call: \(message.content)")
///         case .toolResultMessage(let message):
///             print("Tool result: \(message.content)")
///         case .usageUpdated(let usage):
///             print("Tokens: \(usage.totalTokens)")
///         case .cleared:
///             print("History cleared")
///         case .error(let error):
///             print("Error: \(error)")
///         }
///     }
/// }
/// ```
public enum ConversationEvent: Sendable {
    /// A user message was appended.
    case userMessage(LLMMessage)

    /// An assistant message was appended.
    case assistantMessage(LLMMessage)

    /// A message asking for tools to be called was appended.
    ///
    /// Sent in place of an assistant event whenever the appended message carries tool calls, so a
    /// UI that only handles assistant events shows nothing for a turn that reached for a tool.
    case toolCallMessage(LLMMessage)

    /// A message carrying tool results was appended.
    ///
    /// Sent in place of a user event, even though tool results travel in the user role, and it
    /// does not advance the turn count.
    case toolResultMessage(LLMMessage)

    /// The running token total changed, carrying the new total rather than the increment.
    case usageUpdated(TokenUsage)

    /// The history was cleared.
    case cleared

    /// A request against this history failed.
    ///
    /// Reported for observers only; the call that failed still throws, so this is not a substitute
    /// for handling the error where it was raised.
    case error(LLMError)
}
