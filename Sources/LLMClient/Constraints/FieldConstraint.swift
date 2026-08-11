/// A JSON Schema keyword applied to a single field of a structured output.
///
/// Pass constraints to `@StructuredField` and the macro writes them into the generated schema as
/// the matching JSON Schema keywords — `.minLength(1)` becomes `minLength: 1`, `.format(.dateTime)`
/// becomes `format: "date-time"`.
///
/// Whether a constraint is enforced depends on the provider. Providers accept different subsets of
/// JSON Schema, so a provider's schema adapter strips the keywords its endpoint rejects and records
/// each one as a `RemovedConstraint`. Those can be turned back into an `outputConstraint` prompt
/// component and stated to the model in words instead. Keywords that survive into the schema are
/// enforced by the provider's decoder; keywords that end up in the prompt are only a request, so
/// validate the decoded value yourself when the constraint has to hold.
///
/// `.enum` is the one case with no removal record, so a provider that ignores it produces neither
/// a schema error nor a prompt fallback — the model is simply free to answer off the list.
///
/// ```swift
/// @Structured("Product information")
/// struct Product {
///     @StructuredField("Product name", .minLength(1), .maxLength(100))
///     var name: String
///
///     @StructuredField("Price", .minimum(0))
///     var price: Int
///
///     @StructuredField("Tags", .minItems(1), .maxItems(10))
///     var tags: [String]
///
///     @StructuredField("Category", .enum(["electronics", "clothing", "food"]))
///     var category: String
/// }
/// ```
public enum FieldConstraint: Sendable, Equatable {
    // MARK: - Array Constraints

    /// The fewest elements an array field may hold.
    case minItems(Int)

    /// The most elements an array field may hold.
    case maxItems(Int)

    // MARK: - Numeric Constraints

    /// The smallest value a numeric field may take, inclusive.
    case minimum(Int)

    /// The largest value a numeric field may take, inclusive.
    case maximum(Int)

    /// A lower bound a numeric field must stay strictly above.
    case exclusiveMinimum(Int)

    /// An upper bound a numeric field must stay strictly below.
    case exclusiveMaximum(Int)

    // MARK: - String Constraints

    /// The fewest characters a string field may hold.
    case minLength(Int)

    /// The most characters a string field may hold.
    case maxLength(Int)

    /// A regular expression the whole string has to match.
    ///
    /// The pattern travels to the provider as written, so keep it to the ECMA-262 syntax JSON
    /// Schema specifies rather than the NSRegularExpression dialect used on device.
    case pattern(String)

    // MARK: - Enum Constraint

    /// The exact set of values the field may take.
    ///
    /// The strongest constraint here, because a provider that supports it decodes against the list
    /// and cannot return anything else. It is also the only one with no removal record, so a
    /// provider that drops it does so silently.
    case `enum`([String])

    // MARK: - Format Constraints

    /// The shape a string field has to follow.
    case format(StringFormat)

    /// A value for the JSON Schema format keyword.
    ///
    /// Format is an annotation rather than a hard rule in JSON Schema, and providers vary in
    /// whether they enforce it at all. Treat it as a strong hint to the model and parse the
    /// returned string defensively.
    public enum StringFormat: String, Sendable, Equatable {
        /// An address in mailbox form, such as name@example.com.
        case email

        /// An absolute URI, scheme included.
        case uri

        /// A UUID in its hyphenated 8-4-4-4-12 form.
        case uuid

        /// A calendar date in YYYY-MM-DD form.
        case date

        /// A time of day in HH:MM:SS form.
        case time

        /// A combined date and time in ISO 8601 form.
        ///
        /// The only case whose wire value differs from its Swift name: it is sent as `date-time`.
        case dateTime = "date-time"

        /// A dotted-quad IPv4 address, such as 192.0.2.1.
        case ipv4

        /// A colon-separated IPv6 address.
        case ipv6

        /// A DNS host name, such as api.example.com.
        case hostname

        /// A length of time in ISO 8601 duration form, such as P3DT4H.
        case duration
    }
}

// MARK: - Convenience Extensions

extension FieldConstraint {
    /// Both element-count bounds for a range, as a two-element array.
    ///
    /// `@StructuredField` takes its constraints variadically and reads them as source syntax, so an
    /// array cannot be handed to it and a range literal is not recognized. Write the two cases out
    /// there instead; this helper is for assembling constraint lists in ordinary code.
    ///
    /// ```swift
    /// FieldConstraint.items(1...5)  // [.minItems(1), .maxItems(5)]
    /// ```
    public static func items(_ range: ClosedRange<Int>) -> [FieldConstraint] {
        [.minItems(range.lowerBound), .maxItems(range.upperBound)]
    }

    /// Both numeric bounds for a range, as a two-element array.
    ///
    /// The bounds are inclusive on each side, matching the closed range. Same caveat as the
    /// element-count helper: `@StructuredField` cannot take the array, so write `.minimum` and
    /// `.maximum` out in the attribute.
    ///
    /// ```swift
    /// FieldConstraint.range(1...5)  // [.minimum(1), .maximum(5)]
    /// ```
    public static func range(_ range: ClosedRange<Int>) -> [FieldConstraint] {
        [.minimum(range.lowerBound), .maximum(range.upperBound)]
    }

    /// Both string-length bounds for a range, as a two-element array.
    ///
    /// Same caveat as the other range helpers: `@StructuredField` cannot take the array, so write
    /// `.minLength` and `.maxLength` out in the attribute.
    ///
    /// ```swift
    /// FieldConstraint.length(3...20)  // [.minLength(3), .maxLength(20)]
    /// ```
    public static func length(_ range: ClosedRange<Int>) -> [FieldConstraint] {
        [.minLength(range.lowerBound), .maxLength(range.upperBound)]
    }
}
