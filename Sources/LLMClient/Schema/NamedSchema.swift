import Foundation

// MARK: - NamedSchema

/// A schema together with the property name it is bound to and whether the model has to fill it in.
///
/// It is the unit the ``SchemaFieldBuilder`` DSL collects: a list of these becomes an object
/// schema through `JSONSchema.object(fields:)`, which is how a dynamic tool declares the
/// parameters it accepts.
///
/// ```swift
/// let field = JSONSchema.string(description: "Display name")
///     .named("name")
/// ```
public struct NamedSchema: Sendable {
    /// The property name the model sees.
    public let name: String

    /// What the value has to look like.
    public let schema: JSONSchema

    /// Whether the name goes into the object's required list.
    public let isRequired: Bool

    /// Creates a named field.
    ///
    /// - Parameters:
    ///   - name: The property name the model sees.
    ///   - schema: What the value has to look like.
    ///   - isRequired: Whether the name goes into the object's required list.
    public init(name: String, schema: JSONSchema, isRequired: Bool = true) {
        self.name = name
        self.schema = schema
        self.isRequired = isRequired
    }
}

// MARK: - Modifiers

extension NamedSchema {
    /// Returns the field marked as one the model has to fill in.
    ///
    /// Fields are already required by default, so this only undoes an earlier `optional()`.
    public func required() -> NamedSchema {
        NamedSchema(name: name, schema: schema, isRequired: true)
    }

    /// Returns the field marked as one the model may leave out.
    ///
    /// The name is kept out of the object's required list. Under a provider whose strict mode
    /// admits no optional property, the adapter puts the name back into the list and makes the
    /// value nullable instead, so what the model may omit becomes a value it may return as null.
    public func optional() -> NamedSchema {
        NamedSchema(name: name, schema: schema, isRequired: false)
    }
}

// MARK: - SchemaFieldBuilder Support

/// Anything the schema field DSL can accept as one of its statements.
public protocol NamedSchemaConvertible: Sendable {
    /// Returns the field this value stands for.
    func asNamedSchema() -> NamedSchema
}

extension NamedSchema: NamedSchemaConvertible {
    public func asNamedSchema() -> NamedSchema {
        self
    }
}
