// GeneratedImage.swift
// swift-llm-client
//
// Image content produced by a model.

import Foundation

// MARK: - GeneratedMediaProtocol

/// Media a model produced, carried as bytes the caller already owns.
///
/// The output-side counterpart of `MediaContentProtocol`, which describes media sent *to* a model.
/// Conforming values hold their bytes in memory, so saving or re-encoding them costs no further
/// network round trip and nothing about them expires.
///
/// ## Conforming Types
/// - `GeneratedImage`
/// - `GeneratedAudio`
/// - `GeneratedVideo` — the exception: it may hold no bytes at all and only a provider-hosted URL.
public protocol GeneratedMediaProtocol: Sendable, Codable, Equatable {
    /// The decoded payload.
    ///
    /// Providers deliver most media as Base64; conforming types decode it once at construction, so
    /// this is always raw bytes rather than a Base64 string.
    var data: Data { get }

    /// The MIME type describing the bytes, such as `image/png`.
    var mimeType: String { get }

    /// The file extension for the bytes, with no leading dot.
    var fileExtension: String { get }
}

// MARK: - GeneratedMediaProtocol Default Implementation

extension GeneratedMediaProtocol {
    /// Writes the bytes to a file.
    ///
    /// The URL is used exactly as given; no extension is appended or checked. A video that holds
    /// only a remote URL has no bytes yet, so saving it writes a zero-length file — download the
    /// data first.
    ///
    /// - Parameter url: Destination file URL.
    /// - Throws: An error if the bytes cannot be written to that location.
    public func save(to url: URL) throws {
        try data.write(to: url)
    }

    /// Joins a base name to the media's own extension.
    ///
    /// - Parameter baseName: Name without an extension.
    public func suggestedFileName(baseName: String = "generated") -> String {
        "\(baseName).\(fileExtension)"
    }
}

// MARK: - GeneratedImage

/// An image a model produced, held whole in memory.
///
/// Returned by OpenAI DALL·E and GPT-Image and by Gemini image generation. The bytes travel with
/// the value, so nothing here refers to a hosted asset and nothing expires.
///
/// ## Provider Differences
/// - **OpenAI**: may fill in the revised prompt, because the endpoint rewrites prompts before
///   rendering. Returns PNG, JPEG, or WebP.
/// - **Gemini**: arrives interleaved with text inside one response, and only ever as PNG.
///
/// ## Example
/// ```swift
/// let image = try await client.generateImage(
///     input: "A cat sitting on a window sill",
///     model: .gptImage
/// )
///
/// try image.save(to: URL(fileURLWithPath: "cat.png"))
///
/// // On UIKit platforms only.
/// if let uiImage = image.uiImage {
///     imageView.image = uiImage
/// }
/// ```
public struct GeneratedImage: GeneratedMediaProtocol {
    // MARK: - Properties

    /// The image bytes, already Base64-decoded.
    public let data: Data

    /// The encoding of the bytes, which fixes both the MIME type and the file extension.
    public let format: ImageOutputFormat

    /// The prompt the provider actually rendered, when it rewrote the one that was sent.
    ///
    /// OpenAI's image endpoints revise prompts for safety and quality and report the revision here.
    /// Gemini never sets it. When a result does not match the request, this is usually the
    /// explanation.
    public let revisedPrompt: String?

    // MARK: - GeneratedMediaProtocol

    /// The MIME type of the bytes, taken from the format.
    public var mimeType: String { format.mimeType }

    /// The file extension for the bytes, taken from the format.
    public var fileExtension: String { format.fileExtension }

    // MARK: - Initializers

    /// Creates an image from decoded bytes.
    ///
    /// - Parameters:
    ///   - data: Raw image bytes, not Base64.
    ///   - format: Encoding of the bytes. It is taken on trust and never verified against them.
    ///   - revisedPrompt: The prompt the provider rendered, if it revised the one that was sent.
    public init(
        data: Data,
        format: ImageOutputFormat,
        revisedPrompt: String? = nil
    ) {
        self.data = data
        self.format = format
        self.revisedPrompt = revisedPrompt
    }

    /// Creates an image by decoding the Base64 payload a provider returned.
    ///
    /// - Parameters:
    ///   - base64String: Base64-encoded image data, exactly as the API delivered it.
    ///   - format: Encoding of the decoded bytes.
    ///   - revisedPrompt: The prompt the provider rendered, if it revised the one that was sent.
    /// - Throws: `GeneratedMediaError.invalidBase64Data` if the string is not valid Base64.
    public init(
        base64String: String,
        format: ImageOutputFormat,
        revisedPrompt: String? = nil
    ) throws {
        guard let data = Data(base64Encoded: base64String) else {
            throw GeneratedMediaError.invalidBase64Data
        }
        self.data = data
        self.format = format
        self.revisedPrompt = revisedPrompt
    }

    // MARK: - Metadata

    /// Size of the image in bytes.
    public var dataSize: Int {
        data.count
    }

    /// The bytes re-encoded as Base64.
    ///
    /// Encoding runs on every access and allocates a string roughly a third larger than the image.
    /// Store the result if you need it more than once.
    public var base64String: String {
        data.base64EncodedString()
    }

    /// The image as a data URL, ready to drop into HTML or CSS.
    ///
    /// For example, `data:image/png;base64,iVBORw0KGgo...`. It embeds the whole Base64 payload, so
    /// it is roughly a third larger than the image itself and is rebuilt on every access.
    public var dataURL: String {
        "data:\(mimeType);base64,\(base64String)"
    }
}

// MARK: - GeneratedMediaError

/// Failures raised while decoding, storing, or fetching generated media.
public enum GeneratedMediaError: Error, Sendable, LocalizedError {
    /// The string handed to a Base64 initializer could not be decoded.
    case invalidBase64Data

    /// Bytes that could not be read as an image.
    ///
    /// Nothing in this package raises it: the initializers trust the format they are given and
    /// never decode the pixels. It is here for callers that do decode and want a matching error.
    case invalidImageData

    /// Writing the media to disk failed, wrapping the underlying file-system error.
    ///
    /// Nothing in this package raises it; saving propagates the write error unwrapped.
    case saveError(Error)

    /// Fetching a provider-hosted asset failed, wrapping the underlying transport error.
    ///
    /// Raised when downloading a video whose bytes live behind a remote URL.
    case downloadError(Error)

    /// A download was asked for on a value that holds no remote URL.
    ///
    /// There is nothing to fetch and nothing to fall back on, so this is raised rather than
    /// returning the value untouched: an empty video that reports success writes a zero-length file
    /// and blames the provider for it.
    case noRemoteURL

    /// The provider answered the download with a non-success HTTP status.
    ///
    /// The body of such a response is an error page, not media, so it is refused rather than stored
    /// as the asset. Expired provider links are the usual cause.
    case downloadHTTPStatus(code: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidBase64Data:
            return "Invalid Base64 encoded data"
        case .invalidImageData:
            return "Invalid image data"
        case .saveError(let error):
            return "Failed to save file: \(error.localizedDescription)"
        case .downloadError(let error):
            return "Failed to download: \(error.localizedDescription)"
        case .noRemoteURL:
            return "No remote URL to download from"
        case .downloadHTTPStatus(let code):
            return "Download failed with HTTP status \(code)"
        }
    }
}

// MARK: - Codable

extension GeneratedImage {
    private enum CodingKeys: String, CodingKey {
        case data
        case format
        case revisedPrompt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(Data.self, forKey: .data)
        self.format = try container.decode(ImageOutputFormat.self, forKey: .format)
        self.revisedPrompt = try container.decodeIfPresent(String.self, forKey: .revisedPrompt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(format, forKey: .format)
        try container.encodeIfPresent(revisedPrompt, forKey: .revisedPrompt)
    }
}
