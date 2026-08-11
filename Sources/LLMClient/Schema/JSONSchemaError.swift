import Foundation

// MARK: - JSONSchemaError

/// An error raised while turning a schema into JSON.
///
/// Encoding failures from `JSONEncoder` itself surface as `EncodingError` and do not come through
/// here.
public enum JSONSchemaError: Error, Sendable {
    /// The encoded schema could not be read back as UTF-8 text.
    ///
    /// Thrown only by ``JSONSchema/toJSONString(prettyPrinted:)``. Since `JSONEncoder` emits
    /// UTF-8, there is no input that reaches it in practice; catch `EncodingError` for the
    /// failures that do happen.
    case encodingFailed
}

// MARK: - LocalizedError

extension JSONSchemaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "The encoded JSON Schema could not be read back as UTF-8 text"
        }
    }
}
