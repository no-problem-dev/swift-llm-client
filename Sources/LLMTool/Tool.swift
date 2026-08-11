import Foundation
import LLMClient

// MARK: - Tool Protocol

/// A function the model may call during a turn.
///
/// Conforming types are usually produced by the `@Tool` macro, which derives the name,
/// description and argument schema from the declaration and synthesizes `execute(with:)`
/// around a `call()` method you write by hand.
///
/// ## Declaring a tool with the macro
///
/// ```swift
/// @Tool("Returns the current weather for a city.")
/// struct GetWeather {
///     // Configuration property (optional)
///     var apiKey: String?
///
///     @ToolArgument("City name")
///     var location: String
///
///     @ToolArgument("Temperature unit", .enum(["celsius", "fahrenheit"]))
///     var unit: String?
///
///     func call() async throws -> String {
///         // Call the weather API
///         return "Tokyo: sunny, 25°C"
///     }
/// }
/// ```
///
/// ## Offering it to the model
///
/// ```swift
/// let tools = ToolSet {
///     GetWeather(apiKey: "xxx")
///     SearchWeb()
///     Calculator()
/// }
/// ```
public protocol Tool: Sendable {
    /// The identifier the model uses to call this tool.
    ///
    /// Providers require it to match `^[a-zA-Z0-9_-]{1,64}$`. Keep it unique within a tool set:
    /// lookup returns the first match, so a second tool under the same name never runs.
    var toolName: String { get }

    /// The prose the model reads when deciding whether to call this tool.
    ///
    /// It is the only basis the model has for choosing between tools, so describe when the tool
    /// applies rather than what it is. It ships with every request of the turn and is charged as
    /// input tokens each time, which is the standing cost of keeping the tool attached.
    var toolDescription: String { get }

    /// The JSON Schema for the arguments the model has to produce.
    ///
    /// It is sent to the provider after per-provider adaptation, and it also drives argument
    /// coercion, so the declared types decide which loosely typed values from a small model can
    /// still be decoded.
    var inputSchema: JSONSchema { get }

    /// Text this tool wants appended to the system prompt whenever it is attached.
    ///
    /// Background the model needs before it can use the tool well — schema notes, worked
    /// examples — belongs to the tool rather than to the caller's prompt, and the loop runtime
    /// appends it to the end of the system prompt. It is charged as system-prompt tokens, not as
    /// part of the tool definition. Defaults to `nil`, appending nothing.
    var systemInstruction: String? { get }

    /// Runs the tool against the arguments the model produced.
    ///
    /// Implementing it as an instance method lets the body read configuration properties that
    /// were set when the tool was constructed. When the call arrives through a tool set, the
    /// arguments have already been coerced against the schema.
    ///
    /// - Parameter argumentsData: The raw JSON arguments carried by the tool call.
    /// - Returns: The result to hand back to the model. Return a `ToolResult.error` for a failure
    ///   the model should see and recover from.
    /// - Throws: A decoding error when the arguments do not fit the schema, or any error the
    ///   implementation raises. A thrown error propagates to the caller instead of reaching the
    ///   model as a tool result.
    func execute(with argumentsData: Data) async throws -> ToolResult
}

// MARK: - TurnEndingTool

/// A tool whose successful result ends the agent turn instead of feeding another round of inference.
///
/// On a non-error result from such a tool, the loop runtime finishes the turn without sending
/// the result back to the model, saving one round trip and the tokens it would cost. Error
/// results still go to the model and the loop continues, so the model can correct itself or
/// apologise.
///
/// A marker protocol, separating the declaration (the tool layer) from its enforcement (the loop
/// runtime).
public protocol TurnEndingTool: Tool {}

// MARK: - TranscriptAwareTool

/// A tool that needs the conversation as it stands at the moment it runs.
///
/// The loop runtime hands such a tool the message list it is holding *right then* — not a
/// snapshot taken when the turn began, so it includes tool calls and results that completed
/// earlier in the same run. The list is passed by value, so a tool cannot mutate the loop's
/// history.
///
/// The last entry is the assistant message carrying the tool call currently executing, and its
/// matching result does not exist yet. Feeding that transcript straight into a downstream LLM
/// call is rejected by providers as an unbalanced tool use, so trimming it is the tool's own
/// responsibility — the tool is the only party that knows its own name.
///
/// Separates the declaration (the tool layer) from its enforcement (the loop runtime).
public protocol TranscriptAwareTool: Tool {
    /// Runs the tool with the conversation available to it.
    ///
    /// - Parameters:
    ///   - argumentsData: The raw JSON arguments, already coerced against the schema.
    ///   - transcript: The conversation as of this moment, as a read-only copy.
    func execute(with argumentsData: Data, transcript: [LLMMessage]) async throws -> ToolResult
}

// MARK: - Tool Convenience Properties

extension Tool {
    /// Appends nothing to the system prompt.
    public var systemInstruction: String? { nil }

    /// Shorthand spelling of the tool identifier.
    public var name: String { toolName }

    /// Shorthand spelling of the tool description.
    public var description: String { toolDescription }
}

// MARK: - EmptyArguments

/// The arguments type of a tool that takes no parameters.
///
/// The `@Tool` macro aliases the generated `Arguments` type to this one when the declaration
/// carries no `@ToolArgument` property, so it rarely has to be written out.
///
/// ```swift
/// @Tool("Returns the current date and time.")
/// struct GetCurrentTime {
///     // No arguments — EmptyArguments is used automatically
///
///     func call() async throws -> String {
///         return ISO8601DateFormatter().string(from: Date())
///     }
/// }
/// ```
@Structured
public struct EmptyArguments {
    public init() {}
}
