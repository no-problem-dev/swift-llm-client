import Foundation

// MARK: - SchemaFieldBuilder

/// A result builder that collects schema fields written one per line into a list.
///
/// It exists so the parameters of a tool can be declared the way SwiftUI declares a view body —
/// a statement per field, with `if` and `for` available — instead of assembling a dictionary of
/// properties and a separate list of required names by hand. Feed the result to
/// `JSONSchema.object(fields:)`, or let a dynamic tool's `parameters` closure take it directly.
///
/// ```swift
/// let tool = DynamicTool("get_weather", description: "Returns the current weather") {
///     JSONSchema.string(description: "City name").named("city")
///     JSONSchema.enum(["celsius", "fahrenheit"], description: "Temperature unit")
///         .named("unit").optional()
/// } handler: { args in
///     .text("Weather in \(args.string("city") ?? "unknown")")
/// }
/// ```
@resultBuilder
public struct SchemaFieldBuilder {
    public static func buildBlock(_ components: NamedSchemaConvertible...) -> [NamedSchema] {
        components.map { $0.asNamedSchema() }
    }

    public static func buildBlock(_ components: [NamedSchema]...) -> [NamedSchema] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: NamedSchemaConvertible) -> [NamedSchema] {
        [expression.asNamedSchema()]
    }

    /// Enables an if statement with no else branch, where a false condition contributes no field
    /// at all rather than an optional one.
    public static func buildOptional(_ component: [NamedSchema]?) -> [NamedSchema] {
        component ?? []
    }

    /// Enables an if/else pair whose branches may declare entirely different fields.
    public static func buildEither(first component: [NamedSchema]) -> [NamedSchema] {
        component
    }

    /// Enables an if/else pair whose branches may declare entirely different fields.
    public static func buildEither(second component: [NamedSchema]) -> [NamedSchema] {
        component
    }

    /// Enables a for loop, appending the fields from each iteration in loop order.
    public static func buildArray(_ components: [[NamedSchema]]) -> [NamedSchema] {
        components.flatMap { $0 }
    }

    public static func buildFinalResult(_ component: [NamedSchema]) -> [NamedSchema] {
        component
    }
}
