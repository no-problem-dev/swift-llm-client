import StructuredDataCore

/// The arguments handed to a dynamic tool's handler.
///
/// An alias for the neutral `StructuredValue` representation, so a handler can read values
/// through its type-safe accessors (`string(_:)`, `int(_:)`, dynamic member lookup, typed
/// subscripts) without declaring a Swift type to decode into.
///
/// ```swift
/// let tool = DynamicTool("get_weather", description: "Returns the weather") {
///     JSONSchema.string(description: "City name").named("city")
/// } handler: { (args: ToolArguments) in
///     let city = args.string("city") ?? "unknown"
///     return .text("Weather in \(city): 25°C")
/// }
/// ```
public typealias ToolArguments = StructuredValue
