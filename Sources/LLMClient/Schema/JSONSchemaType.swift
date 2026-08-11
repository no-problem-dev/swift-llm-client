import Foundation

// MARK: - JSONSchemaType

/// The type keyword of a JSON Schema node.
///
/// These seven are the whole vocabulary: a node is one of them, never a union of two, and there
/// is no case for the composition keywords. The one union that does occur is with null, which
/// ``JSONSchema/nullable`` handles rather than a case here.
///
/// ```swift
/// let schema = JSONSchema(type: .string, description: "Full name")
/// let objectSchema = JSONSchema(type: .object, properties: ["name": .string()])
/// ```
public enum JSONSchemaType: String, Sendable, Codable, Equatable {
    /// A collection of named properties, and the type a structured-output schema normally takes
    /// at its root.
    case object

    /// An ordered list whose element type is declared by the items keyword.
    case array

    case string

    /// A whole number, and the narrower of the two numeric types.
    ///
    /// Worth preferring wherever a fractional value would be meaningless, since it is the schema,
    /// not the prompt, that then rules one out.
    case integer

    /// A number that may have a fractional part.
    case number

    case boolean

    /// The null value, and nothing else. To let a value be null *or* something else, set
    /// ``JSONSchema/nullable`` on that value's own schema instead of using this case.
    case null
}
