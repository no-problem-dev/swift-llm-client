import Foundation

// MARK: - JSONSchema Factory Methods

extension JSONSchema {
    /// Creates a schema for a string value.
    ///
    /// Of the constraints here, only `enum` reaches every provider intact. Lengths and patterns
    /// are dropped for at least one of them, and `format` for two of the three, so anything that
    /// really has to hold belongs in `description` as well.
    ///
    /// ```swift
    /// let nameSchema = JSONSchema.string(description: "Full name", minLength: 1)
    /// let emailSchema = JSONSchema.string(format: "email")
    /// ```
    ///
    /// - Parameters:
    ///   - description: Natural-language text the model reads when filling this value in.
    ///   - minLength: The fewest characters allowed.
    ///   - maxLength: The most characters allowed.
    ///   - pattern: A regular expression the value has to match.
    ///   - format: A named format such as `"email"` or `"uri"`.
    ///   - enumValues: The complete set of values allowed.
    public static func string(
        description: String? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil,
        format: String? = nil,
        enum enumValues: [String]? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .string,
            description: description,
            minLength: minLength,
            maxLength: maxLength,
            pattern: pattern,
            enum: enumValues,
            format: format
        )
    }

    /// Creates a schema for a whole number.
    ///
    /// The bounds are declared as `Double` but the type keyword stays `integer`, so a model that
    /// honours the schema returns a whole number. Only Gemini enforces the bounds; elsewhere they
    /// are dropped and have to be restated in the prompt.
    ///
    /// ```swift
    /// let ageSchema = JSONSchema.integer(description: "Age in years", minimum: 0, maximum: 150)
    /// ```
    ///
    /// - Parameters:
    ///   - description: Natural-language text the model reads when filling this value in.
    ///   - minimum: The smallest value allowed, inclusive.
    ///   - maximum: The largest value allowed, inclusive.
    ///   - exclusiveMinimum: The bound the value has to stay strictly above.
    ///   - exclusiveMaximum: The bound the value has to stay strictly below.
    public static func integer(
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        exclusiveMinimum: Double? = nil,
        exclusiveMaximum: Double? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .integer,
            description: description,
            minimum: minimum,
            maximum: maximum,
            exclusiveMinimum: exclusiveMinimum,
            exclusiveMaximum: exclusiveMaximum
        )
    }

    /// Creates a schema for a number that may have a fractional part.
    ///
    /// Only inclusive bounds are offered here; for exclusive ones build the value through
    /// `init(type:…)` directly, though no provider adapter keeps them.
    ///
    /// ```swift
    /// let priceSchema = JSONSchema.number(description: "Price in yen", minimum: 0)
    /// ```
    ///
    /// - Parameters:
    ///   - description: Natural-language text the model reads when filling this value in.
    ///   - minimum: The smallest value allowed, inclusive.
    ///   - maximum: The largest value allowed, inclusive.
    public static func number(
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .number,
            description: description,
            minimum: minimum,
            maximum: maximum
        )
    }

    /// Creates a schema for a boolean value.
    ///
    /// ```swift
    /// let isActiveSchema = JSONSchema.boolean(description: "Whether the account is active")
    /// ```
    ///
    /// - Parameter description: Natural-language text the model reads when filling this value in.
    public static func boolean(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .boolean, description: description)
    }

    /// Creates a schema whose only allowed value is null.
    ///
    /// This is rarely what you want. To say "this value may be absent", leave the property out of
    /// the object's `required` list, or set `nullable` on the property's own schema — that is how
    /// optionality survives a provider whose strict mode requires every property.
    ///
    /// ```swift
    /// let nullSchema = JSONSchema.null(description: "Always null")
    /// ```
    ///
    /// - Parameter description: Natural-language text the model reads when filling this value in.
    public static func null(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .null, description: description)
    }

    /// Creates a schema for an array of like-typed elements.
    ///
    /// The element schema is required: an array without one leaves the model free to put anything
    /// in it. The counts survive only on Gemini — Anthropic accepts a `minItems` of 0 or 1 and
    /// nothing else, and OpenAI strict mode takes neither count.
    ///
    /// ```swift
    /// let tagsSchema = JSONSchema.array(
    ///     description: "Tags describing the article",
    ///     items: .string(),
    ///     minItems: 1,
    ///     maxItems: 10
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - description: Natural-language text the model reads when filling this value in.
    ///   - items: The schema every element has to match.
    ///   - minItems: The fewest elements allowed.
    ///   - maxItems: The most elements allowed.
    public static func array(
        description: String? = nil,
        items: JSONSchema,
        minItems: Int? = nil,
        maxItems: Int? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .array,
            description: description,
            items: items,
            minItems: minItems,
            maxItems: maxItems
        )
    }

    /// Creates a schema for an object with declared properties.
    ///
    /// Additional properties are refused by default, which is both what OpenAI strict mode
    /// requires and what keeps a model from inventing fields the decoder then has to ignore. Any
    /// property missing from `required` is optional as written, but a strict provider cannot
    /// express that: its adapter puts every property in `required` and makes the optional ones
    /// nullable instead.
    ///
    /// ```swift
    /// let userSchema = JSONSchema.object(
    ///     description: "A user record",
    ///     properties: [
    ///         "name": .string(description: "Full name"),
    ///         "age": .integer(minimum: 0)
    ///     ],
    ///     required: ["name", "age"]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - description: Natural-language text the model reads when filling this object in.
    ///   - properties: The properties of the object, keyed by name.
    ///   - required: Names of the properties the model has to fill in.
    ///   - additionalProperties: Whether properties beyond the declared ones are allowed.
    public static func object(
        description: String? = nil,
        properties: [String: JSONSchema],
        required: [String]? = nil,
        additionalProperties: Bool = false
    ) -> JSONSchema {
        JSONSchema(
            type: .object,
            description: description,
            properties: properties,
            required: required,
            additionalProperties: additionalProperties
        )
    }

    /// Creates a string schema restricted to a fixed set of values.
    ///
    /// Reach for this before writing the alternatives out in prose. Enumerations are the one
    /// validation keyword every provider adapter passes through untouched, so the constraint is
    /// enforced while decoding rather than merely requested of the model.
    ///
    /// ```swift
    /// let statusSchema = JSONSchema.enum(
    ///     ["active", "inactive", "pending"],
    ///     description: "Current account status"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - values: The complete set of values allowed.
    ///   - description: Natural-language text the model reads when choosing among them.
    public static func `enum`(
        _ values: [String],
        description: String? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .string,
            description: description,
            enum: values
        )
    }

    /// Creates an object schema from named fields, splitting them into properties and a required
    /// list.
    ///
    /// This is the form the ``SchemaFieldBuilder`` DSL produces, and how a tool declares its
    /// parameters. Every field is required unless marked otherwise, and when none of them are the
    /// `required` keyword is left off entirely rather than encoded as an empty array. Two fields
    /// sharing a name collapse into one property, the last one winning.
    ///
    /// ```swift
    /// let schema = JSONSchema.object(fields: [
    ///     JSONSchema.string(description: "Full name").named("name"),
    ///     JSONSchema.integer(minimum: 0).named("age").optional(),
    /// ])
    /// ```
    ///
    /// - Parameters:
    ///   - description: Natural-language text the model reads when filling this object in.
    ///   - fields: The object's fields, each carrying its name and whether it is required.
    ///   - additionalProperties: Whether properties beyond the declared ones are allowed.
    public static func object(
        description: String? = nil,
        fields: [NamedSchema],
        additionalProperties: Bool = false
    ) -> JSONSchema {
        var properties: [String: JSONSchema] = [:]
        var required: [String] = []
        for field in fields {
            properties[field.name] = field.schema
            if field.isRequired { required.append(field.name) }
        }
        return .object(
            description: description,
            properties: properties,
            required: required.isEmpty ? nil : required,
            additionalProperties: additionalProperties
        )
    }
}

// MARK: - JSONSchema Named Extension

extension JSONSchema {
    /// Attaches a field name to this schema so it can stand as a property of an object.
    ///
    /// The result is required by default; chain `optional()` to leave it out of the object's
    /// required list.
    ///
    /// ```swift
    /// let field = JSONSchema.string(description: "Display name")
    ///     .named("name")
    ///
    /// let optionalField = JSONSchema.integer(minimum: 0)
    ///     .named("age")
    ///     .optional()
    /// ```
    ///
    /// - Parameter name: The property name the model sees.
    public func named(_ name: String) -> NamedSchema {
        NamedSchema(name: name, schema: self, isRequired: true)
    }
}
