import Foundation

// MARK: - JSONSchema

/// A JSON Schema describing the JSON a model is required to produce.
///
/// Use it for structured output — the shape the response must take — and for the arguments of a
/// tool. Write the schema once for every provider: a ``ProviderSchemaAdapter`` reduces it to the
/// subset the target endpoint accepts just before the request goes out, and reports back
/// whatever it had to drop.
///
/// Only the seven types in ``JSONSchemaType`` are modelled. There is no representation for
/// `anyOf`, `oneOf`, `allOf`, `$ref`, or `$schema`, so those keywords cannot be expressed here
/// and never reach a provider.
///
/// ## Example
///
/// ```swift
/// let userSchema = JSONSchema.object(
///     description: "A user record",
///     properties: [
///         "name": .string(description: "Full name"),
///         "age": .integer(minimum: 0, maximum: 150)
///     ],
///     required: ["name", "age"]
/// )
///
/// let jsonData = try userSchema.toJSONData()
/// ```
///
/// ## Provider differences
///
/// Providers accept different subsets of JSON Schema and reject the request outright when an
/// unsupported keyword appears. Declare the constraints you actually want rather than the lowest
/// common denominator: the adapter strips what the target cannot take and hands back a
/// ``RemovedConstraint`` for each one, which the caller can restate in the system prompt so the
/// requirement still reaches the model. ``ProviderSchemaAdapter`` lists what each provider keeps.
public struct JSONSchema: Sendable, Codable, Equatable {
    /// The type keyword for this node.
    ///
    /// Encoding pairs it with ``nullable``: a nullable node goes out as a `["<type>", "null"]`
    /// union instead of a bare string. Decoding accepts either form.
    public let type: JSONSchemaType

    /// Whether the value is allowed to be null as well.
    ///
    /// Encoded by widening the type into a `["<type>", "null"]` union rather than as a keyword of
    /// its own. OpenAI strict mode has no optional property — every property must be listed in
    /// `required` — so optionality is expressed as nullability there, and its adapter sets this
    /// on each property the caller left out of ``required``.
    public let nullable: Bool

    /// Natural-language description of this node, passed straight through to the model.
    ///
    /// This is prompt text, not API documentation: the model reads it when deciding what to put
    /// here, and it costs input tokens on every request carrying the schema. It is also where a
    /// requirement goes when no keyword survives the trip to the provider.
    public let description: String?

    /// The properties of an object, keyed by name.
    ///
    /// Meaningful only when ``type`` is object. Because this is a dictionary, the order the
    /// properties take in the encoded JSON is the encoder's business: ``toJSONData()`` and
    /// ``toJSONString(prettyPrinted:)`` sort keys and produce identical bytes on every run, while
    /// a plain `JSONEncoder` does not — and bytes that shift between runs defeat prompt caching.
    public let properties: [String: JSONSchema]?

    /// Names of the properties the model has to fill in.
    ///
    /// Omitting a property from this list is how optionality is declared, and not every provider
    /// can honour it: under OpenAI strict mode every property is required, so its adapter
    /// rewrites this to name all of them and marks the omitted ones ``nullable`` instead.
    public let required: [String]?

    /// The schema every element of an array has to match.
    ///
    /// Boxed because the element type of a schema is itself a schema; see ``Box``.
    public let items: Box<JSONSchema>?

    /// Whether the model may return properties beyond the declared ones.
    ///
    /// Adapters do not treat this as a preference. OpenAI strict mode requires `false` on every
    /// object and its adapter forces it there; Gemini rejects the keyword and its adapter removes
    /// it. Only the Anthropic adapter sends what you wrote.
    public let additionalProperties: Bool?

    // MARK: - Array constraints

    /// The fewest elements the array may hold.
    ///
    /// Kept as written only for Gemini. The Anthropic adapter keeps 0 and 1 and drops anything
    /// larger; the OpenAI adapter always drops it.
    public let minItems: Int?

    /// The most elements the array may hold.
    ///
    /// Kept only for Gemini; the Anthropic and OpenAI adapters drop it.
    public let maxItems: Int?

    // MARK: - Numeric constraints

    /// The smallest value allowed, inclusive.
    ///
    /// Kept only for Gemini; the Anthropic and OpenAI adapters drop numeric bounds.
    public let minimum: Double?

    /// The largest value allowed, inclusive.
    ///
    /// Kept only for Gemini; the Anthropic and OpenAI adapters drop numeric bounds.
    public let maximum: Double?

    /// The bound the value has to stay strictly above.
    ///
    /// No provider adapter keeps the exclusive bounds — all three drop them and report the
    /// removal, so an exclusive bound only ever reaches the model as prompt text.
    public let exclusiveMinimum: Double?

    /// The bound the value has to stay strictly below.
    ///
    /// Dropped by every provider adapter, like ``exclusiveMinimum``.
    public let exclusiveMaximum: Double?

    // MARK: - String constraints

    /// The fewest characters the string may contain.
    ///
    /// Dropped by every provider adapter. Counted in characters, not tokens, so it is no way to
    /// bound the length of a generation.
    public let minLength: Int?

    /// The most characters the string may contain.
    ///
    /// Dropped by every provider adapter, like ``minLength``.
    public let maxLength: Int?

    /// A regular expression the string has to match.
    ///
    /// Kept only for Anthropic. The OpenAI and Gemini adapters drop it, and a dropped pattern
    /// becomes an instruction in the prompt rather than something the decoder enforces.
    public let pattern: String?

    // MARK: - Enumeration and format

    /// The complete set of values this string is allowed to take.
    ///
    /// The one validation keyword every provider adapter passes through untouched, which makes it
    /// the most dependable way to pin a model down to a fixed vocabulary.
    public let `enum`: [String]?

    /// A named string format such as email, uri, or date-time.
    ///
    /// Anthropic accepts any format, Gemini only date-time, date, and time, and OpenAI strict
    /// mode none at all; the adapter drops what its provider will not take.
    public let format: String?

    // MARK: - Initializer

    /// Creates a schema node from raw keywords.
    ///
    /// Prefer the factory methods — `string(...)`, `object(...)`, `array(...)` — which only offer
    /// the keywords that apply to a type. This initializer accepts every keyword whatever the
    /// type is, and nothing checks that the combination means anything.
    ///
    /// - Parameters:
    ///   - type: The type keyword for this node.
    ///   - nullable: Whether the value may also be null, encoded as a union with the null type
    ///     rather than as a keyword. Set it for a property that is optional under a provider
    ///     whose strict mode requires every property.
    ///   - description: Natural-language text the model reads; it costs input tokens.
    ///   - properties: The properties of an object, keyed by name.
    ///   - required: Names of the properties the model has to fill in.
    ///   - items: The schema every element of an array has to match.
    ///   - additionalProperties: Whether properties beyond the declared ones are allowed.
    ///   - minItems: The fewest elements the array may hold.
    ///   - maxItems: The most elements the array may hold.
    ///   - minimum: The smallest value allowed, inclusive.
    ///   - maximum: The largest value allowed, inclusive.
    ///   - exclusiveMinimum: The bound the value has to stay strictly above.
    ///   - exclusiveMaximum: The bound the value has to stay strictly below.
    ///   - minLength: The fewest characters the string may contain.
    ///   - maxLength: The most characters the string may contain.
    ///   - pattern: A regular expression the string has to match.
    ///   - enum: The complete set of values this string is allowed to take.
    ///   - format: A named string format such as email, uri, or date-time.
    public init(
        type: JSONSchemaType,
        nullable: Bool = false,
        description: String? = nil,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        items: JSONSchema? = nil,
        additionalProperties: Bool? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        exclusiveMinimum: Double? = nil,
        exclusiveMaximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil,
        `enum`: [String]? = nil,
        format: String? = nil
    ) {
        self.type = type
        self.nullable = nullable
        self.description = description
        self.properties = properties
        self.required = required
        self.items = items.map { Box($0) }
        self.additionalProperties = additionalProperties
        self.minItems = minItems
        self.maxItems = maxItems
        self.minimum = minimum
        self.maximum = maximum
        self.exclusiveMinimum = exclusiveMinimum
        self.exclusiveMaximum = exclusiveMaximum
        self.minLength = minLength
        self.maxLength = maxLength
        self.pattern = pattern
        self.enum = `enum`
        self.format = format
    }
}

// MARK: - Convenience Properties

extension JSONSchema {
    public var isObject: Bool { type == .object }

    public var isArray: Bool { type == .array }

    /// Whether this node is a scalar rather than a container.
    ///
    /// True for string, integer, number, boolean, and null; false for object and array.
    public var isPrimitive: Bool {
        switch type {
        case .string, .integer, .number, .boolean, .null:
            return true
        case .object, .array:
            return false
        }
    }
}
