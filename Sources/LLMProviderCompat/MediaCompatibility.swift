// MediaCompatibility.swift
// swift-llm-client
//
// Created by Claude on 2025-12-20.

import Foundation
import LLMCore

// MARK: - Provider Capabilities Protocol

/// What a provider will accept, asked of the provider itself.
public protocol ProviderCapabilities: Sendable {
    /// The provider's name as it should appear to a person, in error messages and logs.
    var displayName: String { get }

    /// Whether this provider accepts the given media type as input.
    func supports<T: MediaType>(_ mediaType: T) -> Bool
}

// MARK: - Provider Type

/// The providers whose media rules this package knows.
///
/// Only the three that accept media input at all. Text-only providers the package can otherwise
/// talk to — Groq, Mistral, xAI, DeepSeek — have no case here, so there is nothing to ask about
/// their media support.
public enum ProviderType: String, Sendable, Codable, ProviderCapabilities {
    case anthropic
    case openai
    case gemini

    /// The provider's name as it should appear to a person.
    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        }
    }

    /// Whether this provider accepts the given media type as input.
    ///
    /// Only the type is checked. Whether the content may be sent as a URL or a file reference is a
    /// separate question, answered by validating the content itself.
    public func supports<T: MediaType>(_ mediaType: T) -> Bool {
        MediaCompatibility.isSupported(mediaType, by: self)
    }
}

// MARK: - Provider Compatibility Error

/// A request rejected before it was sent, because the provider would not have accepted the media.
///
/// Raised by validation rather than by the API, so it costs no round trip and no tokens.
public enum ProviderCompatibilityError: Error, Sendable, Equatable, LocalizedError {
    /// The provider does not offer the capability the content relies on, such as audio input or
    /// sending an image by file reference.
    case notSupportedByProvider(feature: String, provider: ProviderType)

    /// The provider accepts this kind of media but not this encoding of it.
    case unsupportedMediaType(mimeType: String, provider: ProviderType)

    public var errorDescription: String? {
        switch self {
        case .notSupportedByProvider(let feature, let provider):
            return "\(feature) is not supported by \(provider.displayName)"
        case .unsupportedMediaType(let mimeType, let provider):
            return "Media type '\(mimeType)' is not supported by \(provider.displayName)"
        }
    }
}

// MARK: - Media Compatibility Matrix

/// Which provider accepts which media, checked before a request goes out.
///
/// One place holds the provider-specific rules, so the domain value types stay ignorant of them and
/// hand validation here. Consulting this turns a rejection that would have cost a round trip into a
/// local error.
///
/// The matrix is maintained by hand against provider documentation; it is a fast pre-flight check,
/// not a guarantee, and a provider that has since tightened its rules can still refuse.
public enum MediaCompatibility {

    // MARK: - Image Type Compatibility

    /// Image encodings every provider takes: JPEG, PNG, GIF, and WebP.
    ///
    /// Safe ground when the destination provider is not known in advance.
    public static var universalImageTypes: [ImageMediaType] {
        [.jpeg, .png, .gif, .webp]
    }

    /// Image encodings only Gemini takes, namely HEIC and HEIF.
    ///
    /// Both are what an iPhone camera produces by default, so photos picked straight from the
    /// library have to be transcoded for Anthropic and OpenAI.
    public static var geminiOnlyImageTypes: [ImageMediaType] {
        [.heic, .heif]
    }

    /// Whether the provider accepts images in this encoding.
    ///
    /// Gemini takes every encoding the type can express, so it is answered without consulting the
    /// lists above; Anthropic and OpenAI are held to the universal set.
    public static func isSupported(_ type: ImageMediaType, by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic, .openai:
            return universalImageTypes.contains(type)
        case .gemini:
            return true
        }
    }

    // MARK: - Audio Type Compatibility

    /// Audio encodings OpenAI's Chat Completions endpoint takes: WAV and MP3, and nothing else.
    ///
    /// A far narrower set than its speech-to-text endpoints accept; anything else has to be
    /// transcoded before it can go into a chat turn.
    public static var openaiChatAudioTypes: [AudioMediaType] {
        [.wav, .mp3]
    }

    /// Audio encodings Gemini takes, which is all of them.
    public static var geminiAudioTypes: [AudioMediaType] {
        AudioMediaType.allCases
    }

    /// Whether the provider accepts audio in this encoding.
    ///
    /// Anthropic takes no audio input at all, so it refuses every encoding. Gemini takes every one,
    /// answered without consulting the list above. OpenAI is held to WAV and MP3.
    public static func isSupported(_ type: AudioMediaType, by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic:
            return false
        case .openai:
            return openaiChatAudioTypes.contains(type)
        case .gemini:
            return true
        }
    }

    // MARK: - Video Type Compatibility

    /// Whether the provider accepts video in this encoding.
    ///
    /// Gemini is the only one that takes video input at all, and it takes every encoding. Anthropic
    /// and OpenAI refuse all video.
    public static func isSupported(_ type: VideoMediaType, by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic, .openai:
            return false
        case .gemini:
            return true
        }
    }

    // MARK: - Document Type Compatibility

    /// Whether the provider accepts documents in this encoding.
    ///
    /// All three take every document encoding, so this always answers yes. How the pages are billed
    /// differs sharply — PDFs are converted to images and text on the provider's side and can cost
    /// far more tokens than their file size suggests.
    public static func isSupported(_ type: DocumentMediaType, by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic, .openai, .gemini:
            return true
        }
    }

    // MARK: - Image Output Format Compatibility

    /// The encodings the provider will return generated images in.
    ///
    /// Empty for Anthropic, which generates no images. OpenAI returns PNG, JPEG, or WebP; Gemini
    /// returns PNG only. An empty result means the whole capability is missing, not that the
    /// request needs different settings.
    public static func imageOutputFormats(for provider: ProviderType) -> [ImageOutputFormat] {
        switch provider {
        case .anthropic:
            return []
        case .openai:
            return [.png, .jpeg, .webp]
        case .gemini:
            return [.png]
        }
    }

    /// Whether the provider will return a generated image in this encoding.
    public static func isSupported(_ format: ImageOutputFormat, by provider: ProviderType) -> Bool {
        imageOutputFormats(for: provider).contains(format)
    }

    // MARK: - Audio Output Format Compatibility

    /// The encodings the provider will return generated speech in.
    ///
    /// Empty for Anthropic, which generates no audio. OpenAI offers the full range — MP3, Opus,
    /// AAC, FLAC, WAV, PCM — while Gemini returns only raw PCM, which needs a header before most
    /// players will touch it.
    public static func audioOutputFormats(for provider: ProviderType) -> [AudioOutputFormat] {
        switch provider {
        case .anthropic:
            return []
        case .openai:
            return [.mp3, .opus, .aac, .flac, .wav, .pcm]
        case .gemini:
            return [.pcm]
        }
    }

    /// Whether the provider will return generated speech in this encoding.
    public static func isSupported(_ format: AudioOutputFormat, by provider: ProviderType) -> Bool {
        audioOutputFormats(for: provider).contains(format)
    }

    // MARK: - Video Output Format Compatibility

    /// The containers the provider will return generated video in.
    ///
    /// Empty for Anthropic, which generates no video. OpenAI Sora and Gemini Veo both return MP4
    /// and nothing else.
    public static func videoOutputFormats(for provider: ProviderType) -> [VideoOutputFormat] {
        switch provider {
        case .anthropic:
            return []
        case .openai:
            return [.mp4]
        case .gemini:
            return [.mp4]
        }
    }

    /// Whether the provider will return generated video in this container.
    public static func isSupported(_ format: VideoOutputFormat, by provider: ProviderType) -> Bool {
        videoOutputFormats(for: provider).contains(format)
    }

    // MARK: - Generic Media Type Compatibility

    /// Whether the provider accepts this media type, whatever kind of media it is.
    ///
    /// Dispatches on the concrete type at runtime. A media type outside the four known kinds
    /// answers no rather than yes, so an unrecognized type is rejected before it reaches the wire.
    public static func isSupported<T: MediaType>(_ type: T, by provider: ProviderType) -> Bool {
        switch type {
        case let image as ImageMediaType:
            return isSupported(image, by: provider)
        case let audio as AudioMediaType:
            return isSupported(audio, by: provider)
        case let video as VideoMediaType:
            return isSupported(video, by: provider)
        case let document as DocumentMediaType:
            return isSupported(document, by: provider)
        default:
            return false
        }
    }

    // MARK: - Media Type Validation

    /// Rejects a media type the provider will not take.
    ///
    /// The throwing form of the support check, for use at the top of a request path. It looks only
    /// at the type; validating the content itself also covers how the bytes are delivered.
    ///
    /// - Throws: `ProviderCompatibilityError.unsupportedMediaType` if the provider will not take it.
    public static func validateSupport<T: MediaType>(_ type: T, for provider: ProviderType) throws {
        if !isSupported(type, by: provider) {
            throw ProviderCompatibilityError.unsupportedMediaType(
                mimeType: type.mimeType,
                provider: provider
            )
        }
    }

    // MARK: - Content Validation

    /// Rejects image content the provider will not take.
    ///
    /// Checks the encoding, then how the image is delivered: Anthropic has no file-reference
    /// mechanism, so an image uploaded to a provider's file store cannot be pointed at from an
    /// Anthropic request.
    ///
    /// - Throws: `ProviderCompatibilityError` naming whichever rule the content breaks.
    public static func validate(_ image: ImageContent, for provider: ProviderType) throws {
        try validateSupport(image.mediaType, for: provider)

        if image.source.isFileReference && provider == .anthropic {
            throw ProviderCompatibilityError.notSupportedByProvider(
                feature: "File reference",
                provider: provider
            )
        }
    }

    /// Rejects audio content the provider will not take.
    ///
    /// Anthropic is refused outright, since it accepts no audio input. OpenAI is additionally held
    /// to inline Base64: it will not fetch audio from a URL, so the bytes have to be carried in the
    /// request body and counted against its size.
    ///
    /// - Throws: `ProviderCompatibilityError` naming whichever rule the content breaks.
    public static func validate(_ audio: AudioContent, for provider: ProviderType) throws {
        if provider == .anthropic {
            throw ProviderCompatibilityError.notSupportedByProvider(
                feature: "Audio input",
                provider: provider
            )
        }

        try validateSupport(audio.mediaType, for: provider)

        if provider == .openai && !audio.source.isBase64 {
            throw ProviderCompatibilityError.notSupportedByProvider(
                feature: "Audio from URL (use base64)",
                provider: provider
            )
        }
    }

    /// Rejects video content for any provider but Gemini.
    ///
    /// Gemini is the only one that takes video input, and it takes every encoding, so nothing about
    /// the content itself is examined once the provider is right.
    ///
    /// - Throws: `ProviderCompatibilityError.notSupportedByProvider` for Anthropic and OpenAI.
    public static func validate(_ video: VideoContent, for provider: ProviderType) throws {
        if provider != .gemini {
            throw ProviderCompatibilityError.notSupportedByProvider(
                feature: "Video input",
                provider: provider
            )
        }
    }

    /// Rejects document content the provider will not take.
    ///
    /// All three providers take every document encoding, so this passes today whatever it is given.
    /// It stays on the request path so a future narrowing has somewhere to live.
    ///
    /// - Throws: `ProviderCompatibilityError.unsupportedMediaType` if the encoding is refused.
    public static func validate(_ document: DocumentContent, for provider: ProviderType) throws {
        try validateSupport(document.mediaType, for: provider)
    }
}
