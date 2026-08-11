// MediaContent.swift
// swift-llm-client
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Image Content

/// An image to send to a model as input.
///
/// Every provider bills image input as input tokens, roughly in proportion to the pixel area
/// after the provider's own downscaling, so a photograph straight from a camera can cost more
/// than the prompt wrapped around it. Resize before sending when full detail is not needed.
///
/// Building an image never checks it against a provider. Anthropic and OpenAI accept JPEG,
/// PNG, GIF and WebP while Gemini also accepts HEIC and HEIF, and Anthropic rejects a
/// file-reference source outright — those rules live in `MediaCompatibility` in
/// `LLMProviderCompat`, and are applied only when something asks for them.
///
/// ## Example
/// ```swift
/// // Inline bytes
/// let imageData = try Data(contentsOf: imageFileURL)
/// let image = ImageContent.base64(imageData, mediaType: .jpeg)
///
/// // Fetched by the provider
/// let image = ImageContent.url(URL(string: "https://example.com/image.jpg")!, mediaType: .jpeg)
///
/// // From a path, with the format inferred from the extension
/// let image = try ImageContent.file(at: "/path/to/image.jpg")
/// ```
public struct ImageContent: Sendable, Equatable, Codable {
    public let source: MediaSource

    /// The format the provider is told the bytes are in.
    ///
    /// Nothing verifies it against the actual content. For a URL or file-reference source there
    /// are no local bytes to check, and even for inline data only the file extension was
    /// consulted, so a mislabelled file reaches the provider under the wrong MIME type.
    public let mediaType: ImageMediaType

    // MARK: - Initializers

    /// Creates an image from an already-built source and its declared format.
    ///
    /// Prefer the convenience constructors, which pair a source case with the format in one
    /// step and can infer the format from a file extension.
    ///
    /// - Parameters:
    ///   - source: Where the bytes come from.
    ///   - mediaType: The format the provider is told the bytes are in.
    public init(
        source: MediaSource,
        mediaType: ImageMediaType
    ) {
        self.source = source
        self.mediaType = mediaType
    }

    // MARK: - Convenience Initializers

    /// Creates an image whose bytes travel inline in the request.
    ///
    /// Despite the name it takes raw data, not a Base64 string; encoding happens at send time
    /// and inflates the payload by roughly a third.
    ///
    /// - Parameters:
    ///   - data: The undecoded image bytes.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func base64(
        _ data: Data,
        mediaType: ImageMediaType
    ) -> ImageContent {
        ImageContent(source: .base64(data), mediaType: mediaType)
    }

    /// Creates an image the provider is expected to fetch for itself.
    ///
    /// The bytes are never read here, so the URL has to be reachable from the provider's
    /// network and stay reachable until the request is served — a short-lived signed URL can
    /// expire between building the message and sending it.
    ///
    /// - Parameters:
    ///   - url: A publicly reachable HTTP or HTTPS URL.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func url(
        _ url: URL,
        mediaType: ImageMediaType
    ) -> ImageContent {
        ImageContent(source: .url(url), mediaType: mediaType)
    }

    /// Creates an image that points at a file already uploaded to a provider's file API.
    ///
    /// Worth using when the same image is sent across many requests, since the bytes are
    /// uploaded once. Anthropic rejects file-reference image sources, and identifiers are not
    /// portable between providers.
    ///
    /// - Parameters:
    ///   - id: A provider-scoped file identifier, such as a Gemini `files/...` name.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func fileReference(
        _ id: String,
        mediaType: ImageMediaType
    ) -> ImageContent {
        ImageContent(source: .fileReference(id: id), mediaType: mediaType)
    }

    /// Reads a local image file, taking its format from the path extension.
    ///
    /// The whole file is loaded into memory and the extension alone decides the format — the
    /// contents are not inspected. An extension outside the known image formats fails here even
    /// if some provider would have accepted the file.
    ///
    /// - Parameter path: A local filesystem path.
    /// - Throws: `MediaError.unsupportedFormat` when the extension is not a known image
    ///   extension, or `MediaError.fileReadError` when the file cannot be read.
    public static func file(
        at path: String
    ) throws -> ImageContent {
        let url = URL(fileURLWithPath: path)
        return try file(at: url)
    }

    /// Reads an image from a file URL, taking its format from the path extension.
    ///
    /// This always produces an inline source. Passing an HTTP URL downloads it synchronously
    /// rather than deferring the fetch to the provider, so use the URL constructor for that.
    ///
    /// - Parameter url: A file URL.
    /// - Throws: `MediaError.unsupportedFormat` when the extension is not a known image
    ///   extension, or `MediaError.fileReadError` when the file cannot be read.
    public static func file(
        at url: URL
    ) throws -> ImageContent {
        let source = try MediaSource.fromFile(at: url)
        let mediaType = try inferMediaType(from: url)
        return ImageContent(source: source, mediaType: mediaType)
    }

    // MARK: - Private

    private static func inferMediaType(from url: URL) throws -> ImageMediaType {
        let ext = url.pathExtension.lowercased()
        guard let mediaType = ImageMediaType.from(fileExtension: ext) else {
            throw MediaError.unsupportedFormat(ext)
        }
        return mediaType
    }
}

// MARK: - Audio Content

/// Audio to send to a model as input.
///
/// Audio is billed by duration rather than file size, so a compressed hour-long recording still
/// costs an hour's worth of input tokens.
///
/// ## Provider support
/// - **OpenAI**: WAV and MP3, on audio-capable models such as gpt-4o-audio-preview, and only
///   from inline data — a URL or file reference is refused.
/// - **Gemini**: WAV, MP3, AAC, FLAC, OGG and AIFF, from any source.
/// - **Anthropic**: no audio input at all; attaching audio to an Anthropic request fails
///   compatibility checking before the format is even considered.
///
/// ## Example
/// ```swift
/// // Inline bytes
/// let audioData = try Data(contentsOf: audioFileURL)
/// let audio = AudioContent.base64(audioData, mediaType: .wav)
///
/// // From a path, with the format inferred from the extension
/// let audio = try AudioContent.file(at: "/path/to/audio.mp3")
/// ```
public struct AudioContent: Sendable, Equatable, Codable {
    public let source: MediaSource

    /// The format the provider is told the bytes are in.
    ///
    /// Nothing verifies it against the actual content; at most a file extension was consulted.
    public let mediaType: AudioMediaType

    // MARK: - Initializers

    /// Creates an audio clip from an already-built source and its declared format.
    ///
    /// - Parameters:
    ///   - source: Where the bytes come from.
    ///   - mediaType: The format the provider is told the bytes are in.
    public init(source: MediaSource, mediaType: AudioMediaType) {
        self.source = source
        self.mediaType = mediaType
    }

    // MARK: - Convenience Initializers

    /// Creates an audio clip whose bytes travel inline in the request.
    ///
    /// The only form OpenAI accepts for audio input. Despite the name it takes raw data, not a
    /// Base64 string.
    ///
    /// - Parameters:
    ///   - data: The undecoded audio bytes.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func base64(_ data: Data, mediaType: AudioMediaType) -> AudioContent {
        AudioContent(source: .base64(data), mediaType: mediaType)
    }

    /// Creates an audio clip the provider is expected to fetch for itself.
    ///
    /// Gemini takes audio this way; OpenAI refuses it and requires inline data instead.
    ///
    /// - Parameters:
    ///   - url: A publicly reachable HTTP or HTTPS URL.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func url(_ url: URL, mediaType: AudioMediaType) -> AudioContent {
        AudioContent(source: .url(url), mediaType: mediaType)
    }

    /// Creates an audio clip that points at a file already uploaded to a provider's file API.
    ///
    /// Suited to long recordings, which are usually too large to carry inline. OpenAI refuses
    /// this form for audio input.
    ///
    /// - Parameters:
    ///   - id: A provider-scoped file identifier, such as a Gemini `files/...` name.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func fileReference(_ id: String, mediaType: AudioMediaType) -> AudioContent {
        AudioContent(source: .fileReference(id: id), mediaType: mediaType)
    }

    /// Reads a local audio file, taking its format from the path extension.
    ///
    /// The whole file is loaded into memory and the contents are not inspected. Container
    /// aliases are resolved on the way in, so an `.m4a` path produces the AAC format.
    ///
    /// - Parameter path: A local filesystem path.
    /// - Throws: `MediaError.unsupportedFormat` when the extension is not a known audio
    ///   extension, or `MediaError.fileReadError` when the file cannot be read.
    public static func file(at path: String) throws -> AudioContent {
        let url = URL(fileURLWithPath: path)
        return try file(at: url)
    }

    /// Reads audio from a file URL, taking its format from the path extension.
    ///
    /// This always produces an inline source. Passing an HTTP URL downloads it synchronously
    /// rather than deferring the fetch to the provider.
    ///
    /// - Parameter url: A file URL.
    /// - Throws: `MediaError.unsupportedFormat` when the extension is not a known audio
    ///   extension, or `MediaError.fileReadError` when the file cannot be read.
    public static func file(at url: URL) throws -> AudioContent {
        let source = try MediaSource.fromFile(at: url)
        let mediaType = try inferMediaType(from: url)
        return AudioContent(source: source, mediaType: mediaType)
    }

    // MARK: - Private

    private static func inferMediaType(from url: URL) throws -> AudioMediaType {
        let ext = url.pathExtension.lowercased()
        guard let mediaType = AudioMediaType.from(fileExtension: ext) else {
            throw MediaError.unsupportedFormat(ext)
        }
        return mediaType
    }
}

// MARK: - Video Content

/// Video to send to a model as input.
///
/// Video is the most expensive input this library carries: it is billed per second of playback,
/// so a short clip costs many times what a single still image does.
///
/// ## Provider support
/// - **Gemini**: MP4, AVI, MOV, MKV, WebM, FLV, MPEG, 3GP and WMV.
/// - **Anthropic and OpenAI**: no video input; reaching them means extracting frames and
///   sending those as images instead.
///
/// ## Example
/// ```swift
/// // A file API reference, which suits the sizes video usually reaches
/// let video = VideoContent.fileReference("files/abc123", mediaType: .mp4)
///
/// // Inline data, workable only for short clips
/// let videoData = try Data(contentsOf: videoFileURL)
/// let video = VideoContent.base64(videoData, mediaType: .mp4)
/// ```
public struct VideoContent: Sendable, Equatable, Codable {
    public let source: MediaSource

    /// The format the provider is told the bytes are in.
    ///
    /// Nothing verifies it against the actual content; at most a file extension was consulted.
    public let mediaType: VideoMediaType

    // MARK: - Initializers

    /// Creates a video from an already-built source and its declared format.
    ///
    /// - Parameters:
    ///   - source: Where the bytes come from.
    ///   - mediaType: The format the provider is told the bytes are in.
    public init(source: MediaSource, mediaType: VideoMediaType) {
        self.source = source
        self.mediaType = mediaType
    }

    // MARK: - Convenience Initializers

    /// Creates a video whose bytes travel inline in the request.
    ///
    /// Practical only for short clips: the data is held in memory and grows by roughly a third
    /// once encoded, and providers cap the size of a single request. Prefer a file API
    /// reference for anything larger.
    ///
    /// - Parameters:
    ///   - data: The undecoded video bytes.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func base64(_ data: Data, mediaType: VideoMediaType) -> VideoContent {
        VideoContent(source: .base64(data), mediaType: mediaType)
    }

    /// Creates a video the provider is expected to fetch for itself.
    ///
    /// - Parameters:
    ///   - url: A publicly reachable HTTP or HTTPS URL.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func url(_ url: URL, mediaType: VideoMediaType) -> VideoContent {
        VideoContent(source: .url(url), mediaType: mediaType)
    }

    /// Creates a video that points at a file already uploaded to a provider's file API.
    ///
    /// The usual way to send video, since the bytes are uploaded once and stay out of the
    /// request body.
    ///
    /// - Parameters:
    ///   - id: A provider-scoped file identifier, such as a Gemini `files/...` name.
    ///   - mediaType: The format the provider is told the bytes are in.
    public static func fileReference(_ id: String, mediaType: VideoMediaType) -> VideoContent {
        VideoContent(source: .fileReference(id: id), mediaType: mediaType)
    }

    /// Reads a local video file, taking its format from the path extension.
    ///
    /// - Parameter path: A local filesystem path.
    /// - Throws: `MediaError.unsupportedFormat` when the extension is not a known video
    ///   extension, or `MediaError.fileReadError` when the file cannot be read.
    ///
    /// - Warning: The entire file is read into memory in one go, which video is large enough to
    ///   make painful. Upload through a provider's file API and use a reference instead.
    public static func file(at path: String) throws -> VideoContent {
        let url = URL(fileURLWithPath: path)
        return try file(at: url)
    }

    /// Reads a video from a file URL, taking its format from the path extension.
    ///
    /// - Parameter url: A file URL.
    /// - Throws: `MediaError.unsupportedFormat` when the extension is not a known video
    ///   extension, or `MediaError.fileReadError` when the file cannot be read.
    ///
    /// - Warning: The entire file is read into memory in one go, which video is large enough to
    ///   make painful. Upload through a provider's file API and use a reference instead.
    public static func file(at url: URL) throws -> VideoContent {
        let source = try MediaSource.fromFile(at: url)
        let mediaType = try inferMediaType(from: url)
        return VideoContent(source: source, mediaType: mediaType)
    }

    // MARK: - Private

    private static func inferMediaType(from url: URL) throws -> VideoMediaType {
        let ext = url.pathExtension.lowercased()
        guard let mediaType = VideoMediaType.from(fileExtension: ext) else {
            throw MediaError.unsupportedFormat(ext)
        }
        return mediaType
    }
}

// MARK: - Media Content Protocol

/// The shared shape of every media input type.
///
/// Conformance lets an image, audio clip, video or document be handled uniformly wherever only
/// the origin of the bytes and the MIME string matter — logging, size accounting, or building a
/// request body.
public protocol MediaContentProtocol: Sendable, Equatable, Codable {
    /// Where the bytes come from.
    var source: MediaSource { get }

    /// The MIME type string handed to the provider.
    var mimeType: String { get }
}

extension ImageContent: MediaContentProtocol {
    public var mimeType: String { mediaType.mimeType }
}

extension AudioContent: MediaContentProtocol {
    public var mimeType: String { mediaType.mimeType }
}

extension VideoContent: MediaContentProtocol {
    public var mimeType: String { mediaType.mimeType }
}
