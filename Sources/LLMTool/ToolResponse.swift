import Foundation
import LLMClient

// MARK: - ToolResponse

/// The answer to one tool call, ready to be handed back to the model.
///
/// Every call the model made needs one of these carrying its id, and they belong in the message
/// that directly follows the assistant message that made the calls. Leave one out and providers
/// reject the whole conversation, so a tool that failed still has to answer — as an error
/// result, which the model can read and recover from.
///
/// ## Example
///
/// ```swift
/// // Answering a call after running the tool
/// let call: ToolCall = ...
/// let output = try await executeTool(call).stringValue
///
/// let response = ToolResponse(
///     callId: call.id,
///     name: call.name,
///     content: .success(output)
/// )
///
/// // Reporting a failure back to the model
/// let errorResponse = ToolResponse(
///     callId: call.id,
///     name: call.name,
///     content: .failure("API rate limit exceeded")
/// )
/// ```
public struct ToolResponse: Sendable, Equatable {
    /// The id of the call being answered, copied verbatim from it.
    public let callId: String

    /// The name of the tool that ran. Providers that have no call id of their own pair results
    /// with calls by this name instead.
    public let name: String

    /// What the tool produced, and whether it succeeded.
    ///
    /// A failure is not an exception: it goes back to the model as ordinary content, so the
    /// message it carries is read by the model and should say what went wrong and what to try
    /// next.
    public let content: ToolResultContent

    /// Images returned by the tool, sent to the model as content in their own right.
    ///
    /// They are billed as image input, so a tool that returns screenshots or charts can cost
    /// far more per call than its text suggests.
    public let mediaContents: [ImageContent]

    // MARK: - Initializer

    public init(
        callId: String, name: String, content: ToolResultContent,
        mediaContents: [ImageContent] = []
    ) {
        self.callId = callId
        self.name = name
        self.content = content
        self.mediaContents = mediaContents
    }

    // MARK: - Convenience

    /// The text the model will see, whether the tool succeeded or failed.
    public var output: String { content.contentValue }

    /// Whether the tool reported a failure.
    public var isError: Bool { content.isError }
}
