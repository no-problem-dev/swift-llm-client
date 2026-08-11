// MARK: - Macro Declarations

/// Turns a struct into a shape the model can be asked to fill in.
///
/// Applied to a struct, it synthesises:
/// - a `public static var jsonSchema` describing the struct as a JSON Schema object
/// - an extension conforming the type to `StructuredProtocol`, `Codable`, and `Sendable`
///
/// Only structs are supported; anything else is a compile-time error. Use `@StructuredEnum` for a
/// string-backed enumeration.
///
/// ## How the schema is built
///
/// - **Which properties are included.** Stored properties that carry an explicit type annotation.
///   Computed properties are skipped, and so — silently — is a property written without a type
///   annotation (`var name = "unknown"`): it stays `Codable` but never appears in the schema, so
///   the model is never asked for it. Annotate every property that should be generated.
/// - **Names are converted to snake_case.** `postalCode` becomes `postal_code` in the schema, so
///   that is the key the model returns. The synthesised `Codable` conformance uses the Swift
///   spelling, so decoding must go through a decoder with `keyDecodingStrategy` set to
///   `.convertFromSnakeCase`.
/// - **Optionality decides requiredness.** Non-optional properties are listed in `required`;
///   optional ones are not, which is how a field is made genuinely skippable.
/// - **`additionalProperties` is always `false`**, so the model cannot invent extra keys.
/// - **Nested types are referenced, not inlined.** A property whose base type is not a Swift
///   primitive emits `TheType.jsonSchema`, so that type must itself be `@Structured` or
///   `@StructuredEnum` or the code will not compile. This holds for arrays of such types too.
///
/// ## How the description reaches the model
///
/// The argument becomes the schema's top-level `description`, which is sent with the request and
/// read by the model as instructions. It has to be a plain string literal: only the first segment
/// of an interpolated literal survives, so `@Structured("Data for \(name)")` silently sends
/// `"Data for "`.
///
/// ## Example
///
/// ```swift
/// @Structured("User information")
/// struct UserInfo {
///     @StructuredField("User name")
///     var name: String
///
///     @StructuredField("Age", .minimum(0), .maximum(150))
///     var age: Int
///
///     @StructuredField("Email address", .format(.email))
///     var email: String?
/// }
/// ```
///
/// ## Generated JSON Schema
///
/// ```json
/// {
///   "type": "object",
///   "description": "User information",
///   "properties": {
///     "name": { "type": "string", "description": "User name" },
///     "age": { "type": "integer", "description": "Age", "minimum": 0, "maximum": 150 },
///     "email": { "type": "string", "description": "Email address", "format": "email" }
///   },
///   "required": ["name", "age"],
///   "additionalProperties": false
/// }
/// ```
///
/// - Parameter description: What this type is, sent to the model as the schema's `description`.
@attached(member, names: named(jsonSchema))
@attached(extension, conformances: StructuredProtocol, Codable, Sendable)
public macro Structured(
    _ description: String? = nil
) = #externalMacro(module: "LLMMacros", type: "StructuredMacro")

/// Describes and constrains one property of a structured type.
///
/// Generates no code of its own. It is a marker that `@Structured` reads off the property while
/// expanding, which is why it only has an effect inside a type carrying that macro — on a property
/// of an ordinary struct it does nothing at all.
///
/// The description becomes that field's `description` in the JSON Schema, which is sent with the
/// request and is what the model reads to decide what belongs in the field. It is the main lever on
/// extraction quality: an unlabelled field leaves the model guessing from the property name alone.
///
/// **Arguments must be literals.** Both the description and every constraint value are read from
/// the source text at expansion time, so `.minimum(minimumAge)` — or any other non-literal
/// expression — is dropped without warning, and only the first segment of an interpolated
/// description survives. Write the values out.
///
/// ## Example
///
/// ```swift
/// @Structured("Product information")
/// struct Product {
///     // Description only
///     @StructuredField("Product name")
///     var name: String
///
///     // Description plus one constraint
///     @StructuredField("Price", .minimum(0))
///     var price: Int
///
///     // Description plus several constraints
///     @StructuredField("Tags", .minItems(1), .maxItems(10))
///     var tags: [String]
///
///     // Restricted to a fixed set of values
///     @StructuredField("Category", .enum(["electronics", "clothing", "food"]))
///     var category: String
///
///     // Format constraint
///     @StructuredField("Website", .format(.uri))
///     var website: String?
/// }
/// ```
///
/// ## Available constraints
///
/// ### Arrays
/// - `.minItems(n)`: fewest elements
/// - `.maxItems(n)`: most elements
///
/// ### Numbers
/// - `.minimum(n)`: lowest value, inclusive
/// - `.maximum(n)`: highest value, inclusive
/// - `.exclusiveMinimum(n)`: lowest value, exclusive
/// - `.exclusiveMaximum(n)`: highest value, exclusive
///
/// ### Strings
/// - `.minLength(n)`: shortest length
/// - `.maxLength(n)`: longest length
/// - `.pattern("regex")`: regular expression the value must match
///
/// ### Enumerations and formats
/// - `.enum(["a", "b", "c"])`: the only values allowed
/// - `.format(.email)`: a named JSON Schema format. `.dateTime` is emitted as `date-time`.
///
/// - Parameters:
///   - description: What this field holds, sent to the model as the field's `description`.
///   - constraints: Constraints to apply, as literals.
@attached(peer)
public macro StructuredField(
    _ description: String,
    _ constraints: FieldConstraint...
) = #externalMacro(module: "LLMMacros", type: "StructuredFieldMacro")

/// Turns a string-backed enumeration into a shape the model can be asked to choose from.
///
/// Applied to an enumeration, it synthesises:
/// - a `public static var jsonSchema` — a string schema constrained to the cases' raw values
/// - a `public static var enumDescription` — a plain-text listing of the cases, for prompts
/// - an extension conforming the type to `StructuredProtocol` and `Sendable`
///
/// The enumeration must declare `String` as its raw value type and must have at least one case;
/// both are compile-time errors otherwise. Each case contributes its explicit raw value when one is
/// written as a string literal, and its case name when one is not.
///
/// ## Example
///
/// ```swift
/// @StructuredEnum("Status")
/// enum Status: String {
///     case active
///     case inactive
///     case pending
/// }
///
/// // With explicit raw values
/// @StructuredEnum("Priority")
/// enum Priority: String {
///     case low = "low"
///     case medium = "medium"
///     case high = "high"
///     case critical = "critical"
/// }
/// ```
///
/// ## Generated JSON Schema
///
/// ```json
/// {
///   "type": "string",
///   "description": "Status",
///   "enum": ["active", "inactive", "pending"]
/// }
/// ```
///
/// ## Using it inside a structured type
///
/// A property of this type expands to the enumeration's own schema, so the allowed values travel
/// with it and no separate wiring is needed:
///
/// ```swift
/// @StructuredEnum
/// enum Status: String {
///     case active, inactive
/// }
///
/// @Structured("Task")
/// struct Task {
///     var title: String
///     var status: Status  // the enum schema is expanded here
/// }
/// ```
///
/// - Parameter description: What this enumeration represents, sent to the model as the schema's
///   `description`. As with `@Structured`, only a plain string literal is read in full.
@attached(member, names: named(jsonSchema), named(enumDescription))
@attached(extension, conformances: StructuredProtocol, Sendable)
public macro StructuredEnum(
    _ description: String? = nil
) = #externalMacro(module: "LLMMacros", type: "StructuredEnumMacro")

/// Explains what one case of a structured enumeration means.
///
/// Generates no code. It is a marker `@StructuredEnum` reads while expanding, so it has an effect
/// only inside an enumeration carrying that macro.
///
/// **The text does not reach the model on its own.** Case descriptions are collected into the
/// generated `enumDescription` string and nowhere else — the JSON Schema still carries only the
/// bare raw values. To let the model use them, put `enumDescription` into the prompt yourself; a
/// description written and then never referenced changes nothing about the output.
///
/// One attribute covers a whole `case` declaration, so `@StructuredCase("…") case low, medium`
/// gives both cases the same text. Write one case per declaration to describe them separately.
///
/// ## Example
///
/// ```swift
/// @StructuredEnum("Task priority")
/// enum Priority: String {
///     @StructuredCase("Not urgent; can be deferred")
///     case low
///
///     @StructuredCase("Ordinary priority")
///     case medium
///
///     @StructuredCase("Urgent; needs attention right away")
///     case high
/// }
/// ```
///
/// ## Resulting enumDescription
///
/// ```
/// Task priority:
/// - low: Not urgent; can be deferred
/// - medium: Ordinary priority
/// - high: Urgent; needs attention right away
/// ```
///
/// - Parameter description: What this case means, for inclusion in `enumDescription`. Must be a
///   plain string literal.
@attached(peer)
public macro StructuredCase(
    _ description: String
) = #externalMacro(module: "LLMMacros", type: "StructuredCaseMacro")
