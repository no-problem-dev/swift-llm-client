import Foundation
import LLMClient

// MARK: - ToolDefinition

/// A serializable description of one tool, as the provider receives it.
///
/// It carries the name, the description and the argument schema, and nothing that can run — no
/// closure, no configuration, no annotations. This is exactly what the model gets to see, and
/// what it is charged input tokens for on every request of the turn.
///
/// ## Example
///
/// ```swift
/// let tools = ToolSet {
///     GetWeather()
///     Calculator()
/// }
///
/// // Read the definitions
/// for definition in tools.definitions {
///     print("Tool: \(definition.name)")
///     print("Description: \(definition.description)")
/// }
/// ```
public struct ToolDefinition: Sendable, Equatable {
    /// The identifier the model calls, matching `^[a-zA-Z0-9_-]{1,64}$`.
    public let name: String

    /// The prose the model reads when choosing between tools.
    public let description: String

    /// The argument schema, before any provider-specific adaptation.
    public let inputSchema: JSONSchema

    public init(name: String, description: String, inputSchema: JSONSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

// MARK: - Tool Extension

extension Tool {
    /// The definition to send to a provider, taken from this tool.
    public var definition: ToolDefinition {
        ToolDefinition(
            name: toolName,
            description: toolDescription,
            inputSchema: inputSchema
        )
    }
}
