/// A type a model can be asked to produce, described to it as a JSON Schema.
///
/// The schema is what constrains generation: it is sent with the request as the response format,
/// and the model's reply is decoded back into this type. A field with no description in the
/// schema is a field the model has to guess at, so descriptions are prompt text, not commentary.
///
/// Conform through `@Structured` (or `@StructuredEnum` for a string-backed enumeration) rather
/// than by hand. The macro emits property names in snake_case, so a hand-written conformance
/// should do the same to stay consistent with what provider clients decode.
///
/// ```swift
/// @Structured("User information")
/// struct UserInfo {
///     @StructuredField("User name")
///     var name: String
///
///     @StructuredField("Age", .minimum(0), .maximum(150))
///     var age: Int
/// }
/// ```
public protocol StructuredProtocol: Codable, Sendable {
    /// The JSON Schema sent to the model to constrain its output.
    ///
    /// Read once per request, so a computed implementation should stay cheap and must return the
    /// same schema every time — a schema that varies between calls breaks prompt caching.
    static var jsonSchema: JSONSchema { get }
}
