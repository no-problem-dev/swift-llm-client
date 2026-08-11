import Foundation
import LLMClient
import JSONParsing

// MARK: - DynamicTool

/// A tool whose name, schema, and behavior are decided at runtime.
///
/// Use it when the set of tools is not known at compile time — tools loaded from a
/// configuration file, forwarded from an MCP server, or built per session — which is exactly
/// what the `@Tool` macro cannot express. Parameters are declared through the schema field
/// builder, and the handler reads argument values through the type-safe accessors on
/// `ToolArguments`.
///
/// ## Example
///
/// ```swift
/// // Parameters declared through the builder
/// let weatherTool = DynamicTool("get_weather", description: "Returns the weather") {
///     JSONSchema.string(description: "City name").named("city")
///     JSONSchema.enum(["celsius", "fahrenheit"], description: "Unit")
///         .named("unit").optional()
/// } handler: { args in
///     let city = args.string("city") ?? "unknown"
///     return .text("Weather in \(city): 25°C")
/// }
///
/// // No parameters
/// let timeTool = DynamicTool("get_time", description: "Returns the current time") {
///     .text(ISO8601DateFormatter().string(from: Date()))
/// }
///
/// // Combined into a tool set
/// let tools = ToolSet {
///     weatherTool
///     timeTool
/// }
/// ```
public struct DynamicTool: Tool, Sendable {
    public let toolName: String
    public let toolDescription: String
    public let inputSchema: JSONSchema
    public let annotations: ToolAnnotations

    private let executeHandler: @Sendable (Data) async throws -> ToolResult

    // MARK: - Init 1: SchemaFieldBuilder DSL + ToolArguments

    /// Creates a tool from declared parameters and a handler that reads parsed arguments.
    ///
    /// The declared fields become an object schema that rejects additional properties, so the
    /// model cannot smuggle in parameters the handler does not expect. Arguments are parsed
    /// before the handler runs, and malformed JSON throws out of `execute(with:)` without ever
    /// reaching the handler.
    ///
    /// - Parameters:
    ///   - name: The name exposed to the model, matching `^[a-zA-Z0-9_-]{1,64}$`.
    ///   - description: What the tool does. The model reads it to decide when to call the tool.
    ///   - annotations: Behavioral hints about the tool, such as whether it is read-only or
    ///     destructive.
    ///   - parameters: Declares the tool's parameters.
    ///   - handler: Runs the tool against the parsed arguments.
    public init(
        _ name: String,
        description: String,
        annotations: ToolAnnotations = ToolAnnotations(),
        @SchemaFieldBuilder parameters: () -> [NamedSchema],
        handler: @escaping @Sendable (ToolArguments) async throws -> ToolResult
    ) {
        let fields = parameters()
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = JSONSchema.object(fields: fields, additionalProperties: false)
        self.annotations = annotations
        self.executeHandler = { data in
            let args = try JSONParser().parse(data)
            return try await handler(args)
        }
    }

    // MARK: - Init 2: SchemaFieldBuilder DSL + raw Data

    /// Creates a tool from declared parameters and a handler that receives the raw argument JSON.
    ///
    /// Prefer this over the parsed-arguments form when the handler forwards the payload
    /// somewhere else — an MCP server, an HTTP call, a decoder of your own — since it avoids
    /// parsing the JSON only to re-encode it.
    ///
    /// - Parameters:
    ///   - name: The name exposed to the model, matching `^[a-zA-Z0-9_-]{1,64}$`.
    ///   - description: What the tool does. The model reads it to decide when to call the tool.
    ///   - annotations: Behavioral hints about the tool, such as whether it is read-only or
    ///     destructive.
    ///   - parameters: Declares the tool's parameters.
    ///   - rawHandler: Runs the tool against the unparsed argument JSON.
    public init(
        _ name: String,
        description: String,
        annotations: ToolAnnotations = ToolAnnotations(),
        @SchemaFieldBuilder parameters: () -> [NamedSchema],
        rawHandler: @escaping @Sendable (Data) async throws -> ToolResult
    ) {
        let fields = parameters()
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = JSONSchema.object(fields: fields, additionalProperties: false)
        self.annotations = annotations
        self.executeHandler = rawHandler
    }

    // MARK: - Init 3: Direct schema + ToolArguments

    /// Creates a tool from a schema you already hold.
    ///
    /// Use it when the schema arrives from outside — an MCP server's tool listing, or a stored
    /// definition — rather than being declared field by field. The schema is passed through
    /// untouched, so any `additionalProperties` policy is the one you supply.
    ///
    /// - Parameters:
    ///   - name: The name exposed to the model, matching `^[a-zA-Z0-9_-]{1,64}$`.
    ///   - description: What the tool does. The model reads it to decide when to call the tool.
    ///   - inputSchema: The schema published to the model for this tool's arguments.
    ///   - annotations: Behavioral hints about the tool, such as whether it is read-only or
    ///     destructive.
    ///   - handler: Runs the tool against the parsed arguments.
    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        annotations: ToolAnnotations = ToolAnnotations(),
        handler: @escaping @Sendable (ToolArguments) async throws -> ToolResult
    ) {
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = inputSchema
        self.annotations = annotations
        self.executeHandler = { data in
            let args = try JSONParser().parse(data)
            return try await handler(args)
        }
    }

    // MARK: - Init 4: No parameters

    /// Creates a tool that takes no arguments.
    ///
    /// The published schema is an empty object that rejects additional properties, and whatever
    /// the model sends is discarded before the handler runs.
    ///
    /// - Parameters:
    ///   - name: The name exposed to the model, matching `^[a-zA-Z0-9_-]{1,64}$`.
    ///   - description: What the tool does. The model reads it to decide when to call the tool.
    ///   - annotations: Behavioral hints about the tool, such as whether it is read-only or
    ///     destructive.
    ///   - handler: Runs the tool.
    public init(
        _ name: String,
        description: String,
        annotations: ToolAnnotations = ToolAnnotations(),
        handler: @escaping @Sendable () async throws -> ToolResult
    ) {
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = JSONSchema.object(properties: [:], additionalProperties: false)
        self.annotations = annotations
        self.executeHandler = { _ in
            try await handler()
        }
    }

    // MARK: - Tool Protocol

    public func execute(with argumentsData: Data) async throws -> ToolResult {
        try await executeHandler(argumentsData)
    }
}
