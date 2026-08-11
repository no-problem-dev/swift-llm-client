import Foundation
import StructuredDataCore
import JSONParsing

// MARK: - ToolCall

/// A single tool invocation the model asked for.
///
/// Carries the call id, the tool name, and the argument JSON. Nothing is executed by holding
/// one: you run the tool and send back a `ToolResponse` carrying the same id.
///
/// ## Example
///
/// ```swift
/// // From a planned response
/// let plan = try await client.planToolCalls(prompt: "Look up the weather", ...)
/// for call in plan.toolCalls {
///     print("Tool: \(call.name)")
///     let args: MyArgs = try call.decodeArguments(as: MyArgs.self)
///     // Run the tool...
/// }
///
/// // From an agent run
/// for try await step in client.runAgent(...) {
///     if case .toolCall(let call) = step {
///         print("Call: \(call.name)")
///     }
/// }
/// ```
public struct ToolCall: Sendable, Equatable {
    /// Identifies this call when the result is sent back.
    ///
    /// Echo it verbatim on the matching tool result. Providers pair calls with results by this
    /// value and reject a conversation where any call is left unanswered, and some providers
    /// have no id of their own, so the value is generated locally and encodes state the next
    /// request needs. Never rewrite, shorten, or regenerate it.
    public let id: String

    /// The name of the tool to run, matching the name published in the tool set.
    public let name: String

    /// The argument JSON exactly as the model produced it.
    ///
    /// Not validated against the tool's schema. Running the call through
    /// `ToolSet.execute(toolNamed:with:)` first coerces values that small models tend to
    /// stringify, such as `{"max_results": "10"}`; decoding this payload directly does not.
    public let arguments: Data

    // MARK: - Initializer

    /// Creates a tool call.
    ///
    /// - Parameters:
    ///   - id: Identifies the call when its result is sent back.
    ///   - name: The name of the tool to run.
    ///   - arguments: The argument JSON.
    public init(id: String, name: String, arguments: Data) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    // MARK: - Decoding

    /// Decodes the arguments into a type of your own.
    ///
    /// Decoding converts from snake case, so the `sort_by` the model sends lands in a `sortBy`
    /// property. The model is free to omit or mistype fields, so a decoding failure is an
    /// ordinary outcome worth reporting back as a tool error rather than a programming defect.
    ///
    /// - Parameter type: The type to decode the arguments into.
    ///
    /// ```swift
    /// struct WeatherArgs: Decodable {
    ///     let location: String
    /// }
    /// let args = try call.decodeArguments(as: WeatherArgs.self)
    /// ```
    public func decodeArguments<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: arguments)
    }

    /// Parses the arguments into a neutral representation with type-safe accessors.
    ///
    /// Use it instead of `decodeArguments(as:)` when there is no argument type to decode into,
    /// as with a tool whose schema was assembled at runtime. The resulting `StructuredValue`
    /// reads the keys exactly as the model sent them, with no snake-case conversion.
    ///
    /// ```swift
    /// let args = try call.argumentsJSON()
    /// if let location = args.string("location") {
    ///     print(location)
    /// }
    /// ```
    public func argumentsJSON() throws -> StructuredValue {
        try JSONParser().parse(arguments)
    }
}
