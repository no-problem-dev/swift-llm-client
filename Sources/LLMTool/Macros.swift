import LLMClient

// MARK: - Tool Macros

/// Defines a struct as a tool the model can call.
///
/// The macro writes everything the tool protocol needs, leaving the type to declare only its
/// arguments and a `call()` method. It synthesizes:
///
/// - conformance to `Tool` and `Sendable`
/// - `toolName` and `toolDescription`
/// - a nested `Arguments` type built from the `@ToolArgument` properties, and the
///   `inputSchema` derived from it
/// - initializers that take the injected properties, plus `execute(with:)`
///
/// It applies to structs only. The type must supply a `call()` method whose return type
/// conforms to `ToolResultConvertible`.
///
/// ## Which properties the model sees
///
/// Every stored property falls into exactly one of three groups, and the group decides whether
/// the model ever learns the property exists:
///
/// - **Arguments** — properties marked `@ToolArgument`. They become the fields of `Arguments`
///   and are the only properties published in the input schema.
/// - **Injected configuration** — properties with no attribute, no default value, and no
///   accessor. They become parameters of the generated initializer, so your own code supplies
///   them when the tool is registered. The model never sees them, which is where API keys,
///   clients, and fetched state belong.
/// - **Ignored** — computed properties, properties with a default value, and anything marked
///   `@ToolExclude`. Neither published nor injected.
///
/// `execute(with:)` decodes the incoming JSON into `Arguments` with `.convertFromSnakeCase`,
/// applies it to a copy of the registered instance, and calls `call()` on that copy. The
/// injected configuration is therefore still readable inside `call()`, while argument values
/// arrive one call at a time and never mutate the registered instance.
///
/// ## Example
///
/// ```swift
/// @Tool("Returns the current weather for a given city")
/// struct GetWeather {
///     // Injected configuration, supplied when the tool is registered.
///     var apiKey: String?
///
///     @ToolArgument("City name (for example, Tokyo or Osaka)")
///     var location: String
///
///     @ToolArgument("Temperature unit", .enum(["celsius", "fahrenheit"]))
///     var unit: String?
///
///     func call() async throws -> String {
///         let weather = try await WeatherAPI.fetch(
///             location: location,
///             unit: unit ?? "celsius",
///             apiKey: apiKey
///         )
///         return "\(location): \(weather.condition), \(weather.temperature)°"
///     }
/// }
/// ```
///
/// ## Registering in a tool set
///
/// ```swift
/// let tools = ToolSet {
///     GetWeather(apiKey: weatherApiKey)
///     SearchWeb()
///     Calculator()
///
///     if needsAdvancedTools {
///         DataAnalyzer()
///     }
/// }
///
/// let plan = try await client.planToolCalls(
///     prompt: "What is the weather in Tokyo?",
///     model: .sonnet,
///     tools: tools
/// )
/// ```
///
/// ## Tools without arguments
///
/// ```swift
/// @Tool("Returns the current date and time")
/// struct GetCurrentTime {
///     // No @ToolArgument property, so the tool takes no arguments.
///
///     func call() async throws -> String {
///         return ISO8601DateFormatter().string(from: Date())
///     }
/// }
/// ```
///
/// ## Return types
///
/// `call()` may return any `ToolResultConvertible` value:
/// - `String`: sent back as text
/// - `Int`, `Double`, `Bool`: converted to text
/// - `Array`, `Dictionary`: encoded as JSON
/// - `ToolResult`: full control, including errors and attached media
/// - a custom type: conform it to `ToolResultConvertible`
///
/// - Parameters:
///   - description: What the tool does. The model reads this to decide when to call the tool,
///     so the more specific it is, the more reliably the tool fires at the right moment.
///   - name: The name exposed to the model. Defaults to the type name converted to snake case,
///     and has to match `^[a-zA-Z0-9_-]{1,64}$`.
@attached(member, names: named(toolName), named(toolDescription), named(inputSchema), named(Arguments), named(arguments), named(init), named(execute))
@attached(extension, conformances: Tool, Sendable)
public macro Tool(
    _ description: String,
    name: String? = nil
) = #externalMacro(module: "LLMMacros", type: "ToolMacro")

/// Excludes a stored property from everything the tool macro generates.
///
/// Without it, a stored property that carries no attribute and no default value becomes a
/// parameter of the generated initializer. Mark the property to keep it out: use this for
/// callbacks and similar members that are neither an argument for the model nor something the
/// initializer should demand. Because the generated initializer will not assign it, the
/// property has to be able to start out on its own, as an optional or with a default value.
///
/// ## Example
///
/// ```swift
/// @Tool("Emits a UI block", name: "emit_block")
/// struct EmitBlockTool {
///     @ToolArgument("Kind of block")
///     var type: String
///
///     @ToolExclude
///     var onEmit: (@Sendable (UIBlock) async -> Void)?
///
///     func call() async throws -> String {
///         await onEmit?(...)
///         return "Done"
///     }
/// }
/// ```
@attached(peer)
public macro ToolExclude() = #externalMacro(module: "LLMMacros", type: "ToolExcludeMacro")

/// Publishes a property of a tool as an argument the model fills in.
///
/// Apply it to stored properties of a type marked `@Tool`. The property becomes a field of the
/// generated `Arguments` type and appears in the input schema sent to the model; every other
/// stored property stays private to your code.
///
/// A non-optional property is published as required, an optional one as optional. The schema
/// exposes the property name in snake case, and the incoming JSON is decoded back with
/// `.convertFromSnakeCase`, so `sortBy` reaches the model as `sort_by` and returns as `sortBy`
/// without any manual mapping.
///
/// ## Example
///
/// ```swift
/// @Tool("Searches for products")
/// struct SearchProducts {
///     // Required argument
///     @ToolArgument("Search keywords")
///     var query: String
///
///     // Optional argument
///     @ToolArgument("Maximum number of results", .minimum(1), .maximum(100))
///     var limit: Int?
///
///     // Argument restricted to a fixed set of values
///     @ToolArgument("Sort order", .enum(["relevance", "price_asc", "price_desc"]))
///     var sortBy: String?
///
///     func call() async throws -> String {
///         // Search logic
///     }
/// }
/// ```
///
/// ## Available constraints
///
/// The same constraints as `@StructuredField`:
///
/// ### Arrays
/// - `.minItems(n)`: fewest elements
/// - `.maxItems(n)`: most elements
///
/// ### Numbers
/// - `.minimum(n)`: lowest value, inclusive
/// - `.maximum(n)`: highest value, inclusive
/// - `.exclusiveMinimum(n)`: lowest value, exclusive
/// - `.exclusiveMaximum(n)`: highest value, exclusive
///
/// ### Strings
/// - `.minLength(n)`: fewest characters
/// - `.maxLength(n)`: most characters
/// - `.pattern("regex")`: regular expression the value has to match
///
/// ### Enumerations and formats
/// - `.enum(["a", "b", "c"])`: the permitted values
/// - `.format(.email)`: the expected format
///
/// - Parameters:
///   - description: What the argument means. The model reads it to decide what value to pass,
///     so it carries as much weight as the type itself.
///   - constraints: Constraints to publish alongside the argument in the schema.
@attached(peer)
public macro ToolArgument(
    _ description: String,
    _ constraints: FieldConstraint...
) = #externalMacro(module: "LLMMacros", type: "ToolArgumentMacro")
