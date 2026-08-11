import Foundation

// MARK: - JSONSchema Encodable Implementation

extension JSONSchema {
    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case required
        case items
        case additionalProperties
        case minItems
        case maxItems
        case minimum
        case maximum
        case exclusiveMinimum
        case exclusiveMaximum
        case minLength
        case maxLength
        case pattern
        case `enum`
        case format
    }

    /// Decodes a schema written by hand or returned by a server, forgivingly.
    ///
    /// Nothing here fails on an unexpected `type`: a missing one, an unrecognized name, and a
    /// union naming no known type all decode as an object, which is what a tool listing from an
    /// MCP server most often means. Keywords this type does not model — `anyOf`, `$ref`,
    /// `$schema` and the rest — are dropped without complaint, so a decode followed by an encode
    /// is not guaranteed to reproduce the input.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `type` is accepted in both forms: a bare string (`"string"`) and a null union
        // (`["string","null"]`).
        var decodedType: JSONSchemaType = .object
        var decodedNullable = false
        if container.contains(.type) {
            if let union = try? container.decode([String].self, forKey: .type) {
                decodedNullable = union.contains(JSONSchemaType.null.rawValue)
                if let primary = union.first(where: { $0 != JSONSchemaType.null.rawValue }),
                   let parsed = JSONSchemaType(rawValue: primary) {
                    decodedType = parsed
                }
            } else if let single = try? container.decode(JSONSchemaType.self, forKey: .type) {
                decodedType = single
            }
        }
        self.init(
            type: decodedType,
            nullable: decodedNullable,
            description: try container.decodeIfPresent(String.self, forKey: .description),
            properties: try container.decodeIfPresent([String: JSONSchema].self, forKey: .properties),
            required: try container.decodeIfPresent([String].self, forKey: .required),
            items: try container.decodeIfPresent(Box<JSONSchema>.self, forKey: .items)?.value,
            additionalProperties: try container.decodeIfPresent(Bool.self, forKey: .additionalProperties),
            minItems: try container.decodeIfPresent(Int.self, forKey: .minItems),
            maxItems: try container.decodeIfPresent(Int.self, forKey: .maxItems),
            minimum: try container.decodeIfPresent(Double.self, forKey: .minimum),
            maximum: try container.decodeIfPresent(Double.self, forKey: .maximum),
            exclusiveMinimum: try container.decodeIfPresent(Double.self, forKey: .exclusiveMinimum),
            exclusiveMaximum: try container.decodeIfPresent(Double.self, forKey: .exclusiveMaximum),
            minLength: try container.decodeIfPresent(Int.self, forKey: .minLength),
            maxLength: try container.decodeIfPresent(Int.self, forKey: .maxLength),
            pattern: try container.decodeIfPresent(String.self, forKey: .pattern),
            enum: try container.decodeIfPresent([String].self, forKey: .enum),
            format: try container.decodeIfPresent(String.self, forKey: .format)
        )
    }

    /// Encodes the schema as JSON Schema, writing only the keywords that were set.
    ///
    /// Nullability has no key of its own: it widens `type` into a union instead. Key order is
    /// left to the encoder — use ``toJSONData()`` or ``toJSONString(prettyPrinted:)`` when the
    /// bytes have to come out the same every run.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // A nullable schema is written as a `["<type>", "null"]` union — how OpenAI strict mode
        // expresses an optional property.
        if nullable {
            try container.encode([type.rawValue, JSONSchemaType.null.rawValue], forKey: .type)
        } else {
            try container.encode(type, forKey: .type)
        }

        if let description {
            try container.encode(description, forKey: .description)
        }
        if let properties {
            try container.encode(properties, forKey: .properties)
        }
        if let required {
            try container.encode(required, forKey: .required)
        }
        if let items {
            try container.encode(items, forKey: .items)
        }
        if let additionalProperties {
            try container.encode(additionalProperties, forKey: .additionalProperties)
        }
        if let minItems {
            try container.encode(minItems, forKey: .minItems)
        }
        if let maxItems {
            try container.encode(maxItems, forKey: .maxItems)
        }
        if let minimum {
            try container.encode(minimum, forKey: .minimum)
        }
        if let maximum {
            try container.encode(maximum, forKey: .maximum)
        }
        if let exclusiveMinimum {
            try container.encode(exclusiveMinimum, forKey: .exclusiveMinimum)
        }
        if let exclusiveMaximum {
            try container.encode(exclusiveMaximum, forKey: .exclusiveMaximum)
        }
        if let minLength {
            try container.encode(minLength, forKey: .minLength)
        }
        if let maxLength {
            try container.encode(maxLength, forKey: .maxLength)
        }
        if let pattern {
            try container.encode(pattern, forKey: .pattern)
        }
        if let `enum` {
            try container.encode(`enum`, forKey: .enum)
        }
        if let format {
            try container.encode(format, forKey: .format)
        }
    }
}

// MARK: - JSON String Conversion

extension JSONSchema {
    /// Encodes the schema as a JSON string with its keys in sorted order.
    ///
    /// Sorting is what makes the output byte-stable: the same schema produces the same string on
    /// every run, whatever order a dictionary of properties happens to iterate in. That matters
    /// when the schema sits inside a cached prompt prefix, where a single reordered key costs the
    /// cache hit.
    ///
    /// ```swift
    /// let schema = JSONSchema.string(description: "Full name")
    /// let jsonString = try schema.toJSONString(prettyPrinted: true)
    /// // {
    /// //   "description": "Full name",
    /// //   "type": "string"
    /// // }
    /// ```
    ///
    /// - Parameter prettyPrinted: Whether to indent the output across several lines.
    /// - Throws: ``JSONSchemaError/encodingFailed`` if the encoded bytes are not valid UTF-8.
    public func toJSONString(prettyPrinted: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = .sortedKeys
        }
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw JSONSchemaError.encodingFailed
        }
        return string
    }

    /// Encodes the schema as JSON data with its keys in sorted order.
    ///
    /// Use this to put the schema into a request body. Like ``toJSONString(prettyPrinted:)`` it
    /// sorts keys, so the bytes are the same on every run and a cached prompt prefix keeps
    /// matching.
    ///
    /// ```swift
    /// let schema = JSONSchema.object(properties: ["name": .string()])
    /// let data = try schema.toJSONData()
    /// ```
    public func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }
}

// MARK: - CustomDebugStringConvertible

extension JSONSchema: CustomDebugStringConvertible {
    /// The schema as pretty-printed JSON, or a bare type name if it cannot be encoded.
    public var debugDescription: String {
        (try? toJSONString(prettyPrinted: true)) ?? "JSONSchema(\(type))"
    }
}
