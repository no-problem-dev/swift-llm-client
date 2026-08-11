import Foundation

// MARK: - ProviderSchemaAdapter

/// Reduces a schema to the subset one provider's endpoint will accept, and says what it took out.
///
/// No provider honours all of JSON Schema, and most reject the whole request when an unsupported
/// keyword appears rather than ignoring it. A conformance carries one provider's rules, so the
/// caller can declare the schema it actually wants and have it trimmed at the edge of the
/// request. What gets trimmed is not lost: ``adaptWithConstraints(_:fieldPath:)`` returns each
/// dropped keyword as a ``RemovedConstraint``, which turns into prompt text so the requirement
/// still reaches the model — as an instruction it may disregard, rather than a rule the decoder
/// enforces.
///
/// ## What the shipped adapters keep
///
/// - Anthropic keeps `pattern`, every `format`, `additionalProperties` as written, and a
///   `minItems` of 0 or 1. It drops the numeric bounds, the string lengths, `maxItems`, and any
///   larger `minItems`.
/// - OpenAI strict mode, and the OpenAI-compatible vendors on the same engine, keep none of the
///   validation keywords. Every object is forced to `additionalProperties: false` and every
///   property is listed in `required`, with the ones the caller left out marked nullable instead.
/// - Gemini keeps `minItems`, `maxItems`, `minimum`, and `maximum`, and the `date-time`, `date`,
///   and `time` formats. It drops the exclusive bounds, the string lengths, `pattern`, other
///   formats, and `additionalProperties` outright.
/// - `enum` survives everywhere, which is what makes it the sturdiest constraint to reach for.
///
/// ## Usage
///
/// ```swift
/// func prepare(
///     _ schema: JSONSchema,
///     for adapter: some ProviderSchemaAdapter,
///     systemPrompt: SystemPrompt
/// ) -> (schema: JSONSchema, systemPrompt: SystemPrompt) {
///     let result = adapter.adaptWithConstraints(schema)
///     guard let constraints = result.toConstraintSystemPrompt() else {
///         return (result.schema, systemPrompt)
///     }
///     return (result.schema, systemPrompt + constraints)
/// }
/// ```
///
/// ## Writing a conformance
///
/// ```swift
/// struct CustomProviderAdapter: ProviderSchemaAdapter {
///     func adapt(_ schema: JSONSchema) -> JSONSchema {
///         adaptWithConstraints(schema).schema
///     }
///
///     func adaptWithConstraints(_ schema: JSONSchema, fieldPath: String) -> SchemaAdaptationResult {
///         // Strip what this provider rejects, recurse into properties and items, and return
///         // the surviving schema alongside a RemovedConstraint for each keyword dropped.
///     }
/// }
/// ```
public protocol ProviderSchemaAdapter: Sendable {
    /// Reduces a schema to what the provider accepts, discarding the record of what was removed.
    ///
    /// The caller gets a schema that will be accepted, and no way to learn what it no longer
    /// says — a `pattern` or a `maximum` can vanish here without ever reaching the model in any
    /// form. Prefer ``adaptWithConstraints(_:fieldPath:)`` whenever the removed constraints can
    /// still be restated in the prompt. Converting a tool set to a provider's format goes through
    /// this method, so constraints on tool parameters are the ones most likely to be lost.
    ///
    /// - Parameter schema: The schema as the caller declared it.
    func adapt(_ schema: JSONSchema) -> JSONSchema

    /// Reduces a schema to what the provider accepts and reports every keyword it had to drop.
    ///
    /// The removals come back tagged with a dotted path to the field they applied to, so they can
    /// be restated as sentences the model can act on. Callers normally use the no-argument
    /// overload; the path argument is for recursing into a nested schema.
    ///
    /// - Parameters:
    ///   - schema: The schema as the caller declared it.
    ///   - fieldPath: The path prefix reported on removed constraints. Nested calls extend it
    ///     with `.property` for a property and `[]` for an array element.
    func adaptWithConstraints(_ schema: JSONSchema, fieldPath: String) -> SchemaAdaptationResult
}

// MARK: - Default Implementation

extension ProviderSchemaAdapter {
    /// Reduces a schema starting from the root, where reported paths are relative to the whole
    /// response.
    ///
    /// A constraint removed at the root itself carries an empty path, which reads as "response"
    /// once turned into prompt text.
    ///
    /// - Parameter schema: The schema as the caller declared it.
    public func adaptWithConstraints(_ schema: JSONSchema) -> SchemaAdaptationResult {
        adaptWithConstraints(schema, fieldPath: "")
    }

    /// Adapts each property of an object, for a conformance that handles one node at a time.
    ///
    /// Constraints removed from the properties are discarded along with everything else
    /// ``adapt(_:)`` drops; use ``adaptPropertiesWithConstraints(_:parentPath:)`` to keep them.
    ///
    /// - Parameter properties: The properties to adapt, or nil for a node that has none.
    public func adaptProperties(_ properties: [String: JSONSchema]?) -> [String: JSONSchema]? {
        properties?.mapValues { adapt($0) }
    }

    /// Adapts each property of an object and gathers the constraints removed anywhere beneath it.
    ///
    /// Paths are built as the walk descends, so a bound removed from the elements of a nested
    /// array is reported as `user.tags[]` rather than as a bare keyword name.
    ///
    /// - Parameters:
    ///   - properties: The properties to adapt, or nil for a node that has none.
    ///   - parentPath: The path of the object these properties belong to. Pass an empty string at
    ///     the root.
    /// - Returns: The adapted properties, and every constraint removed from them.
    public func adaptPropertiesWithConstraints(
        _ properties: [String: JSONSchema]?,
        parentPath: String
    ) -> ([String: JSONSchema]?, [RemovedConstraint]) {
        guard let properties = properties else { return (nil, []) }

        var adaptedProperties: [String: JSONSchema] = [:]
        var allConstraints: [RemovedConstraint] = []

        for (key, value) in properties {
            let fieldPath = parentPath.isEmpty ? key : "\(parentPath).\(key)"
            let result = adaptWithConstraints(value, fieldPath: fieldPath)
            adaptedProperties[key] = result.schema
            allConstraints.append(contentsOf: result.removedConstraints)
        }

        return (adaptedProperties, allConstraints)
    }

    /// Adapts the element schema of an array, unwrapping the box it is stored in.
    ///
    /// Constraints removed from the element type are discarded; use
    /// ``adaptItemsWithConstraints(_:parentPath:)`` to keep them.
    ///
    /// - Parameter items: The boxed element schema, or nil for a node that is not an array.
    public func adaptItems(_ items: Box<JSONSchema>?) -> JSONSchema? {
        items.map { adapt($0.value) }
    }

    /// Adapts the element schema of an array and gathers the constraints removed from it.
    ///
    /// The element type has no name of its own, so its removals are reported under the array's
    /// path with `[]` appended.
    ///
    /// - Parameters:
    ///   - items: The boxed element schema, or nil for a node that is not an array.
    ///   - parentPath: The path of the array itself.
    /// - Returns: The adapted element schema, and every constraint removed from it.
    public func adaptItemsWithConstraints(
        _ items: Box<JSONSchema>?,
        parentPath: String
    ) -> (JSONSchema?, [RemovedConstraint]) {
        guard let items = items else { return (nil, []) }
        let itemPath = "\(parentPath)[]"
        let result = adaptWithConstraints(items.value, fieldPath: itemPath)
        return (result.schema, result.removedConstraints)
    }
}
