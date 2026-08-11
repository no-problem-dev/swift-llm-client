// MediaSource.swift
// swift-llm-client
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Media Source

/// Where the bytes of a piece of media come from.
///
/// Only the inline case actually holds bytes in this process. The other two are promises the
/// provider redeems on its own side, which is why size checks here cannot see them and why
/// providers differ on which cases they accept at all.
///
/// ## Example
/// ```swift
/// // Inline bytes
/// let imageData = try Data(contentsOf: imageFileURL)
/// let source = MediaSource.base64(imageData)
///
/// // Fetched by the provider
/// let source = MediaSource.url(URL(string: "https://example.com/image.jpg")!)
///
/// // Already uploaded through a file API, such as Gemini's
/// let source = MediaSource.fileReference(id: "files/abc123")
/// ```
public enum MediaSource: Sendable, Equatable {
    /// Raw bytes carried inline in the request body.
    ///
    /// The associated value is undecoded data, not a Base64 string. Encoding happens when the
    /// source is read, and it grows the payload by roughly a third on the wire.
    case base64(Data)

    /// An HTTP or HTTPS URL the provider fetches for itself.
    ///
    /// Nothing here downloads it, so it has to be reachable from the provider's network rather
    /// than only from this process.
    case url(URL)

    /// A handle to a file already uploaded through a provider's file API.
    ///
    /// Identifiers are provider-scoped: a Gemini `files/...` name means nothing to OpenAI.
    case fileReference(id: String)

    // MARK: - Convenience Accessors

    /// The Base64 encoding of the inline bytes, or nil for the two remote cases.
    ///
    /// The string is built fresh on every access, so read it once and keep it rather than
    /// touching it repeatedly for a large payload.
    public var base64String: String? {
        guard case .base64(let data) = self else { return nil }
        return data.base64EncodedString()
    }

    /// The URL to be fetched by the provider, or nil for any other case.
    public var urlValue: URL? {
        guard case .url(let url) = self else { return nil }
        return url
    }

    /// The provider-scoped file identifier, or nil for any other case.
    public var fileReferenceId: String? {
        guard case .fileReference(let id) = self else { return nil }
        return id
    }

    /// The undecoded inline bytes, or nil when the media lives on the provider's side.
    public var data: Data? {
        guard case .base64(let data) = self else { return nil }
        return data
    }

    // MARK: - Validation

    /// The undecoded byte count of inline data, or nil when the size is not knowable here.
    ///
    /// The Base64 form sent on the wire is about a third larger than this figure.
    public var dataSize: Int? {
        guard case .base64(let data) = self else { return nil }
        return data.count
    }

    /// Reports whether inline data fits a byte budget, counting anything remote as fitting.
    ///
    /// URL and file-reference sources answer `true` because their size is unknown here, so a
    /// `true` result is not evidence that the provider will accept the media — only that
    /// nothing this process holds is over budget.
    ///
    /// - Parameter maxBytes: The budget, compared against the undecoded byte count rather than
    ///   the longer Base64 form that actually travels in the request.
    public func isWithinSizeLimit(_ maxBytes: Int) -> Bool {
        guard let size = dataSize else { return true }
        return size <= maxBytes
    }

    /// Throws when inline data is over a byte budget, and does nothing for remote sources.
    ///
    /// A URL or file-reference source passes unconditionally, so this cannot stand in for the
    /// provider's own size check.
    ///
    /// - Parameter maxBytes: The budget, compared against the undecoded byte count rather than
    ///   the longer Base64 form that actually travels in the request.
    /// - Throws: `MediaError.sizeLimitExceeded`, carrying both the measured and allowed sizes.
    public func validateSize(maxBytes: Int) throws {
        guard let size = dataSize else { return }
        if size > maxBytes {
            throw MediaError.sizeLimitExceeded(size: size, maxSize: maxBytes)
        }
    }

    // MARK: - Source Type Info

    /// A stable tag for the case, matching the discriminator written by the coding conformance.
    ///
    /// Safe for logs and diagnostics, since it never includes the payload.
    public var sourceType: String {
        switch self {
        case .base64: return "base64"
        case .url: return "url"
        case .fileReference: return "fileReference"
        }
    }

    /// Whether the bytes travel inline rather than being fetched by the provider.
    ///
    /// Provider gating branches on this: OpenAI refuses audio input that is not inline.
    public var isBase64: Bool {
        if case .base64 = self { return true }
        return false
    }

    /// Whether the provider is expected to fetch the media itself.
    public var isURL: Bool {
        if case .url = self { return true }
        return false
    }

    /// Whether the media is a handle to a file already uploaded to a provider.
    ///
    /// Anthropic rejects file-reference image sources, so this is worth checking before a
    /// message is routed there.
    public var isFileReference: Bool {
        if case .fileReference = self { return true }
        return false
    }
}

// MARK: - Codable Implementation

extension MediaSource: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case data
        case url
        case fileId
    }

    private enum SourceType: String, Codable {
        case base64
        case url
        case fileReference
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SourceType.self, forKey: .type)

        switch type {
        case .base64:
            let data = try container.decode(Data.self, forKey: .data)
            self = .base64(data)
        case .url:
            let url = try container.decode(URL.self, forKey: .url)
            self = .url(url)
        case .fileReference:
            let id = try container.decode(String.self, forKey: .fileId)
            self = .fileReference(id: id)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .base64(let data):
            try container.encode(SourceType.base64, forKey: .type)
            try container.encode(data, forKey: .data)
        case .url(let url):
            try container.encode(SourceType.url, forKey: .type)
            try container.encode(url, forKey: .url)
        case .fileReference(let id):
            try container.encode(SourceType.fileReference, forKey: .type)
            try container.encode(id, forKey: .fileId)
        }
    }
}

// MARK: - Convenience Initializers

extension MediaSource {
    /// Reads a local file into an inline source.
    ///
    /// The whole file is loaded into memory at once, so this is a poor fit for anything large
    /// enough to belong in a provider's file API instead.
    ///
    /// - Parameter filePath: A local filesystem path.
    /// - Throws: `MediaError.fileReadError`, wrapping the underlying read failure.
    public static func fromFile(at filePath: String) throws -> MediaSource {
        let url = URL(fileURLWithPath: filePath)
        return try fromFile(at: url)
    }

    /// Reads a file URL into an inline source.
    ///
    /// The URL is handed straight to `Data(contentsOf:)`, which is not restricted to file URLs:
    /// passing an HTTP URL here downloads it synchronously on the calling thread instead of
    /// producing the URL case. Use the URL case directly when the provider should do the fetch.
    ///
    /// - Parameter url: A file URL.
    /// - Throws: `MediaError.fileReadError`, wrapping the underlying read failure.
    public static func fromFile(at url: URL) throws -> MediaSource {
        do {
            let data = try Data(contentsOf: url)
            return .base64(data)
        } catch {
            throw MediaError.fileReadError(error)
        }
    }

    /// Decodes a Base64 string into an inline source.
    ///
    /// Use this when the bytes arrive already encoded, such as from another API's response. The
    /// source stores the decoded data and re-encodes on demand, so nothing is gained by keeping
    /// the string around.
    ///
    /// - Parameter base64String: Plain Base64, with no data-URI prefix — a `data:image/png;base64,`
    ///   header makes decoding fail.
    /// - Throws: `MediaError.invalidMediaData` when the string is not valid Base64.
    public static func fromBase64String(_ base64String: String) throws -> MediaSource {
        guard let data = Data(base64Encoded: base64String) else {
            throw MediaError.invalidMediaData("Invalid Base64 string")
        }
        return .base64(data)
    }
}

// MARK: - CustomStringConvertible

extension MediaSource: CustomStringConvertible {
    /// A one-line summary that reports the byte count instead of the payload.
    ///
    /// Safe to log: inline media never appears in the output, so a multi-megabyte image cannot
    /// be spilled into a log line by interpolating the source.
    public var description: String {
        switch self {
        case .base64(let data):
            return "MediaSource.base64(\(data.count) bytes)"
        case .url(let url):
            return "MediaSource.url(\(url.absoluteString))"
        case .fileReference(let id):
            return "MediaSource.fileReference(\(id))"
        }
    }
}
