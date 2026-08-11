import Foundation

// MARK: - Box

/// A reference wrapper that lets a value type refer back to itself.
///
/// A struct cannot contain itself by value — the compiler cannot give it a size — and a schema's
/// element type is another schema, so ``JSONSchema`` stores its `items` boxed. The indirection
/// exists for that reason alone; the box is invisible in the encoded JSON, since it encodes and
/// decodes as the value it holds rather than as a wrapper around it.
///
/// ```swift
/// // JSONSchema boxes this for you: init takes a plain schema and wraps it.
/// let arraySchema = JSONSchema(type: .array, items: .string())
/// let elementType = arraySchema.items?.value.type  // .string
/// ```
public final class Box<T: Sendable & Encodable & Equatable>: Sendable, Encodable, Equatable {
    public let value: T

    // MARK: - Initializer

    public init(_ value: T) {
        self.value = value
    }

    // MARK: - Encodable

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }

    // MARK: - Equatable

    /// Compares the wrapped values, not the identity of the two boxes.
    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
        lhs.value == rhs.value
    }
}

// MARK: - Decodable

extension Box: Decodable where T: Decodable {
    public convenience init(from decoder: Decoder) throws {
        self.init(try T(from: decoder))
    }
}
