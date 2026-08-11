import Foundation
import LLMClient

// MARK: - ToolResult

/// What a tool produced, on its way back to the model.
///
/// Whatever a tool's `call()` method returns ends up here, as text, as JSON, as an error, or as
/// text with images attached. Everything in it is read by the model and billed as input tokens,
/// so returning the whole of an API payload when three fields would do is what quietly makes a
/// tool-using conversation expensive.
///
/// ## Example
///
/// ```swift
/// // Text
/// return .text("Tokyo: sunny, 25°C")
///
/// // Structured data
/// let data = WeatherData(temp: 25, condition: "sunny")
/// return try ToolResult.encoded(data)
///
/// // Error
/// return .error("API rate limit exceeded")
///
/// // Text with images attached
/// return .textWithMedia("Image loaded", media: [imageContent])
/// ```
public enum ToolResult: Sendable, Equatable {
    /// Plain text.
    case text(String)

    /// Structured data, already encoded as JSON.
    case json(Data)

    /// A failure the model should know about, such as a failed API call or a lookup that found
    /// nothing.
    ///
    /// This is how a tool reports trouble without throwing: the message goes back as content
    /// the model reads, so write it for the model — say what failed and what it could try
    /// instead. Throwing out of `call()` instead propagates to your own code and leaves the
    /// call unanswered.
    case error(String)

    /// Text plus images handed to the model as content in their own right.
    ///
    /// The text becomes the tool result and the images are injected alongside it, which is how
    /// a tool returns something the model has to actually look at. Images are billed as image
    /// input and need a model that accepts them.
    case textWithMedia(String, media: [ImageContent])

    // MARK: - Factory Methods

    /// Encodes a value as a JSON result.
    ///
    /// Keys come out sorted, so the same value always produces the same bytes. That keeps a
    /// replayed conversation byte-identical and lets a cached prefix keep matching.
    ///
    /// - Parameter value: The value to encode.
    ///
    /// ```swift
    /// let weather = WeatherData(temp: 25, condition: "sunny")
    /// return try ToolResult.encoded(weather)
    /// ```
    public static func encoded<T: Encodable>(_ value: T) throws -> ToolResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(value)
        return .json(data)
    }

    // MARK: - Conversion

    /// The result rendered as the text the model will read.
    ///
    /// - `text`: returned unchanged
    /// - `json`: decoded as UTF-8, or empty if the bytes are not valid UTF-8
    /// - `error`: the message prefixed with `Error: `
    /// - `textWithMedia`: the text part only, without the images
    public var stringValue: String {
        switch self {
        case .text(let string):
            return string
        case .json(let data):
            return String(data: data, encoding: .utf8) ?? ""
        case .error(let message):
            return "Error: \(message)"
        case .textWithMedia(let text, _):
            return text
        }
    }

    /// Whether the tool reported a failure.
    public var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// The attached images, empty for every case but the one that carries media.
    public var mediaContents: [ImageContent] {
        if case .textWithMedia(_, let media) = self {
            return media
        }
        return []
    }
}

// MARK: - ToolResultConvertible

/// A type a tool can return directly.
///
/// Conform your own type to it to return it straight from `call()`. The standard types a tool
/// is likely to produce — strings, numbers, booleans, arrays, and dictionaries — already
/// conform. Since the conversion decides what the model actually reads, this is the place to
/// trim a payload down to the fields worth spending tokens on.
///
/// ## Example
///
/// ```swift
/// struct WeatherInfo: ToolResultConvertible, Encodable {
///     let temperature: Int
///     let condition: String
///
///     func asToolResult() throws -> ToolResult {
///         return try ToolResult.encoded(self)
///     }
/// }
/// ```
public protocol ToolResultConvertible {
    /// Converts the value into the result the model receives.
    func asToolResult() throws -> ToolResult
}

// MARK: - Standard Type Conformances

extension String: ToolResultConvertible {
    public func asToolResult() throws -> ToolResult {
        .text(self)
    }
}

extension Int: ToolResultConvertible {
    public func asToolResult() throws -> ToolResult {
        .text(String(self))
    }
}

extension Double: ToolResultConvertible {
    public func asToolResult() throws -> ToolResult {
        .text(String(self))
    }
}

extension Bool: ToolResultConvertible {
    public func asToolResult() throws -> ToolResult {
        .text(String(self))
    }
}

extension Array: ToolResultConvertible where Element: Encodable {
    public func asToolResult() throws -> ToolResult {
        try ToolResult.encoded(self)
    }
}

extension Dictionary: ToolResultConvertible where Key == String, Value: Encodable {
    public func asToolResult() throws -> ToolResult {
        try ToolResult.encoded(self)
    }
}

// MARK: - ToolResult Conformance

extension ToolResult: ToolResultConvertible {
    public func asToolResult() throws -> ToolResult {
        self
    }
}

// MARK: - Codable Types

/// Returns any encodable value as a JSON tool result.
///
/// Use it for a type you cannot conform yourself, such as one from another module.
///
/// ```swift
/// let weather = WeatherData(temp: 25)
/// return try JSONToolResult(weather).asToolResult()
/// ```
public struct JSONToolResult<T: Encodable & Sendable>: ToolResultConvertible, Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }

    public func asToolResult() throws -> ToolResult {
        try ToolResult.encoded(value)
    }
}
