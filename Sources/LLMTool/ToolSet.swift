import Foundation
import LLMClient

// MARK: - ToolSet

/// An ordered collection of the tools offered to the model in one request.
///
/// A result builder assembles it declaratively, so conditionals and loops work the way they do
/// in a SwiftUI view body. Declaration order is preserved throughout — in the definitions sent
/// to the provider, and in name lookup, where the first match wins.
///
/// ## Building a set
///
/// ```swift
/// let tools = ToolSet {
///     GetWeatherTool(apiKey: weatherApiKey)
///     SearchTool()
///
///     if needsCalculator {
///         CalculatorTool()
///     }
///
///     for tool in dynamicTools {
///         tool
///     }
/// }
///
/// let result = try await client.generate(
///     input: "What is the weather in Tokyo?",
///     model: .sonnet,
///     tools: tools
/// )
/// ```
///
/// ## Combining sets
///
/// ```swift
/// let baseTools = ToolSet {
///     GetWeatherTool()
///     SearchTool()
/// }
///
/// let extendedTools = baseTools.appending(CalculatorTool())
/// ```
public struct ToolSet: Sendable {

    // MARK: - Properties

    /// The tools, in the order they were declared.
    public let tools: [any Tool]

    // MARK: - Initializers

    /// Creates a set from a builder body.
    ///
    /// - Parameter builder: A closure that lists the tools to include.
    ///
    /// ```swift
    /// let tools = ToolSet {
    ///     GetWeatherTool()
    ///     SearchTool()
    /// }
    /// ```
    public init(@ToolSetBuilder _ builder: () -> [any Tool]) {
        self.tools = builder()
    }

    /// Creates a set from an existing array, keeping its order and any repeated names.
    public init(tools: [any Tool]) {
        self.tools = tools
    }

    public init() {
        self.tools = []
    }

    // MARK: - Properties

    public var isEmpty: Bool {
        tools.isEmpty
    }

    public var count: Int {
        tools.count
    }

    /// The tool names in declaration order, repeats included.
    public var toolNames: [String] {
        tools.map { $0.name }
    }

    /// The system-prompt additions requested by the tools, in declaration order.
    ///
    /// Tools that ask for nothing are skipped, so this can be shorter than the set itself.
    public var systemInstructions: [String] {
        tools.compactMap { $0.systemInstruction }
    }

    // MARK: - Lookup

    /// Returns the first tool carrying the given name.
    ///
    /// Nothing stops a set from holding two tools under one name, and only the first is ever
    /// found here, so only the first can ever run. The scan is linear and the comparison is
    /// exact, including case.
    ///
    /// - Parameter name: The tool name exactly as it was sent to the provider.
    /// - Returns: The matching tool, or `nil` when the set holds none by that name.
    public func tool(named name: String) -> (any Tool)? {
        tools.first { $0.name == name }
    }

    /// The provider-facing definition of every tool, in declaration order.
    public var definitions: [ToolDefinition] {
        tools.map { $0.definition }
    }

    /// Runs the tool the model asked for by name.
    ///
    /// Arguments are coerced against that tool's schema first, which repairs the numbers and
    /// booleans a small model tends to emit as strings. A tool conforming to
    /// `TranscriptAwareTool` runs through its plain execute path here; reach for the transcript
    /// overload to hand it the conversation.
    ///
    /// - Parameters:
    ///   - name: The tool name carried by the tool call.
    ///   - argumentsData: The raw JSON arguments carried by the tool call.
    /// - Returns: The tool's result.
    /// - Throws: `ToolExecutionError.toolNotFound` when no tool in the set answers to that name,
    ///   which is where a hallucinated tool name lands, or whatever the tool itself throws.
    public func execute(toolNamed name: String, with argumentsData: Data) async throws -> ToolResult {
        guard let tool = tool(named: name) else {
            throw ToolExecutionError.toolNotFound(name)
        }
        // Absorbs the case where a small model emits a number or boolean as a string, following
        // the schema (e.g. {"max_results":"10"} → {"max_results":10}). Valid arguments keep
        // their values.
        let coerced = tool.inputSchema.coerceArguments(argumentsData)
        return try await tool.execute(with: coerced)
    }

    /// Runs the tool the model asked for, offering it the conversation so far.
    ///
    /// A tool conforming to `TranscriptAwareTool` receives the message list; every other tool
    /// takes the same path as in the plain overload. The loop runtime can always call this one,
    /// since the conformance check happens here rather than at the call site.
    ///
    /// - Parameters:
    ///   - name: The tool name carried by the tool call.
    ///   - argumentsData: The raw JSON arguments carried by the tool call.
    ///   - transcript: The conversation as of this moment.
    public func execute(
        toolNamed name: String,
        with argumentsData: Data,
        transcript: [LLMMessage]
    ) async throws -> ToolResult {
        guard let tool = tool(named: name) else {
            throw ToolExecutionError.toolNotFound(name)
        }
        let coerced = tool.inputSchema.coerceArguments(argumentsData)
        if let aware = tool as? any TranscriptAwareTool {
            return try await aware.execute(with: coerced, transcript: transcript)
        }
        return try await tool.execute(with: coerced)
    }
}

// MARK: - ToolExecutionError

/// An error raised while dispatching a tool call.
public enum ToolExecutionError: Error, LocalizedError {
    /// No tool in the set answers to the requested name.
    ///
    /// Either the model invented the name, or the set being executed against differs from the
    /// one whose definitions were sent.
    case toolNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        }
    }
}

// MARK: - ToolSet Combination

extension ToolSet {
    /// Concatenates two sets, keeping the order of both and any name that now appears twice.
    ///
    /// - Parameters:
    ///   - lhs: The tools placed first.
    ///   - rhs: The tools appended after them.
    public static func + (lhs: ToolSet, rhs: ToolSet) -> ToolSet {
        ToolSet(tools: lhs.tools + rhs.tools)
    }

    /// Appends a single tool to a set.
    ///
    /// - Parameters:
    ///   - lhs: The tools placed first.
    ///   - rhs: The tool appended after them.
    public static func + (lhs: ToolSet, rhs: some Tool) -> ToolSet {
        ToolSet(tools: lhs.tools + [rhs])
    }

    /// Returns a new set with another set's tools appended.
    ///
    /// - Parameter other: The tools to append.
    public func appending(_ other: ToolSet) -> ToolSet {
        self + other
    }

    /// Returns a new set with one more tool appended.
    ///
    /// - Parameter tool: The tool to append.
    public func appending(_ tool: some Tool) -> ToolSet {
        self + tool
    }
}

// MARK: - CustomStringConvertible

extension ToolSet: CustomStringConvertible {
    public var description: String {
        let names = toolNames.joined(separator: ", ")
        return "ToolSet(\(count) tools: \(names))"
    }
}

// MARK: - Provider Format Conversion

extension ToolSet {
    /// Converts every tool into a provider's own definition shape.
    ///
    /// The adapter rewrites each schema for the target provider — reshaping or dropping the
    /// keywords that provider rejects — before the builder wraps it up. One entry comes back per
    /// tool, in declaration order; nothing is filtered out along the way.
    ///
    /// - Parameters:
    ///   - adapter: The schema adapter for the target provider.
    ///   - formatBuilder: Builds the provider's definition from a tool and its adapted schema.
    /// - Returns: One provider definition per tool, in declaration order.
    public func toProviderFormat<Definition>(
        adapter: some ProviderSchemaAdapter,
        formatBuilder: (any Tool, _ adaptedSchema: JSONSchema) -> Definition
    ) -> [Definition] {
        tools.compactMap { tool in
            let adaptedSchema = adapter.adapt(tool.inputSchema)
            return formatBuilder(tool, adaptedSchema)
        }
    }
}
