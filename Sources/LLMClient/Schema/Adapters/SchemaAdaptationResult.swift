import Foundation

// MARK: - SchemaAdaptationResult

/// A schema trimmed to fit one provider, together with the keywords that had to go.
///
/// The removals are the reason this type exists. A schema that silently loses a `maximum` still
/// produces valid JSON, just not the JSON that was asked for, so a caller that ignores
/// ``removedConstraints`` has quietly relaxed its own contract. Feed them back into the system
/// prompt with ``toConstraintSystemPrompt()``, which restates each one as a sentence the model
/// can follow. Enforcement moves from the decoder to the model when that happens: the output is
/// no longer rejected for violating the constraint, so validate on the way back in if it matters.
///
/// ```swift
/// let result = adapter.adaptWithConstraints(schema)
/// let schemaForRequest = result.schema
///
/// if let constraintPrompt = result.toConstraintSystemPrompt() {
///     let effectiveSystemPrompt = systemPrompt + constraintPrompt
/// }
/// ```
public struct SchemaAdaptationResult: Sendable {
    /// The schema as it will go on the wire.
    public let schema: JSONSchema

    /// The keywords stripped on the way, each tagged with the field it came from.
    public let removedConstraints: [RemovedConstraint]

    public init(schema: JSONSchema, removedConstraints: [RemovedConstraint] = []) {
        self.schema = schema
        self.removedConstraints = removedConstraints
    }

    /// Whether anything was stripped.
    ///
    /// True means the schema on the wire no longer says everything the caller declared, and the
    /// difference has to be made up in the prompt.
    public var hasRemovedConstraints: Bool {
        !removedConstraints.isEmpty
    }
}

// MARK: - RemovedConstraint

/// One JSON Schema keyword dropped because the target provider does not accept it.
///
/// Everything needed to say the constraint out loud again is here: which keyword, which field,
/// and what value it carried. That is what ``toPromptComponent()`` turns it into.
public struct RemovedConstraint: Sendable, Equatable {
    /// Which keyword was dropped.
    public let type: ConstraintType

    /// Dotted path to the field the keyword applied to.
    ///
    /// A property reads as `user.age` and an array's element type as `items[]`. The path is empty
    /// at the root of the schema, where the generated prompt text calls it "response".
    public let fieldPath: String

    /// The value the keyword carried, kept so it can be repeated to the model.
    public let value: ConstraintValue

    public init(type: ConstraintType, fieldPath: String, value: ConstraintValue) {
        self.type = type
        self.fieldPath = fieldPath
        self.value = value
    }
}

// MARK: - ConstraintType

/// The JSON Schema keywords an adapter is able to drop.
///
/// Only validation keywords appear here. Something a provider rewrites rather than removes —
/// `required` and `additionalProperties` under a strict provider — is not reported as a removal
/// and has no case.
public enum ConstraintType: String, Sendable, Equatable {
    // Numeric bounds
    case minimum
    case maximum
    case exclusiveMinimum
    case exclusiveMaximum

    // Array counts
    case minItems
    case maxItems

    // String shape
    case minLength
    case maxLength
    case pattern

    // Named string format
    case format

    /// A short English phrase naming the keyword, for use in a message to a person.
    ///
    /// Not the text handed to the model — that sentence is built by
    /// ``RemovedConstraint/toPromptComponent()``, which words each keyword itself.
    public var description: String {
        switch self {
        case .minimum: return "minimum value"
        case .maximum: return "maximum value"
        case .exclusiveMinimum: return "exclusive minimum value"
        case .exclusiveMaximum: return "exclusive maximum value"
        case .minItems: return "minimum number of items"
        case .maxItems: return "maximum number of items"
        case .minLength: return "minimum length"
        case .maxLength: return "maximum length"
        case .pattern: return "pattern"
        case .format: return "format"
        }
    }
}

// MARK: - ConstraintValue

/// The value a dropped keyword carried, in whichever shape the keyword uses.
public enum ConstraintValue: Sendable, Equatable {
    case int(Int)
    case double(Double)
    case string(String)

    /// The value as it will be written into the prompt.
    ///
    /// A numeric bound goes through `Double` even on an integer field, since that is how
    /// ``JSONSchema/minimum`` and ``JSONSchema/maximum`` are typed, so a minimum of 0 reaches the
    /// model as "0.0".
    public var stringValue: String {
        switch self {
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .string(let value): return value
        }
    }
}

