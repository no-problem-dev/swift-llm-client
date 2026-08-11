// LLMInputProtocol.swift
// swift-llm-client
//
// Created by Claude on 2025-12-21.

import Foundation

// MARK: - LLMInputProtocol

/// A prompt plus the images, audio, and video that accompany it.
///
/// Conform a custom type when a request should be assembled from a domain object rather than
/// from `LLMInput`. Only `prompt` has to be supplied; the media requirements default to empty,
/// so a text-only conformance is a single property.
///
/// The protocol carries no notion of which provider will serve the request, so conformances can
/// hold media a given provider will refuse. `validate(for:)` is what turns that into an error
/// before the request leaves the process.
///
/// ## Example
///
/// ```swift
/// // Text only
/// let input = LLMInput("Hello")
///
/// // Multimodal
/// let input = LLMInput(
///     "Analyze this image.",
///     images: [imageContent]
/// )
///
/// // Using the SystemPrompt DSL
/// let input = LLMInput(
///     SystemPrompt {
///         PromptComponent.role("Data analysis expert")
///         PromptComponent.objective("Extract information from the image")
///     },
///     images: [imageContent]
/// )
/// ```
public protocol LLMInputProtocol: Sendable {
    /// The prompt text.
    var prompt: SystemPrompt { get }

    /// Images to send with the prompt.
    var images: [ImageContent] { get }

    /// Audio to send with the prompt.
    var audios: [AudioContent] { get }

    /// Video to send with the prompt.
    var videos: [VideoContent] { get }
}

// MARK: - Default Implementations

extension LLMInputProtocol {
    /// No images unless the conforming type provides some.
    public var images: [ImageContent] { [] }

    /// No audio unless the conforming type provides some.
    public var audios: [AudioContent] { [] }

    /// No video unless the conforming type provides some.
    public var videos: [VideoContent] { [] }

    /// Whether anything other than text is attached.
    ///
    /// Use it to decide whether `validate(for:)` is worth calling, or to pick a model that can
    /// accept media in the first place.
    public var hasMediaContent: Bool {
        !images.isEmpty || !audios.isEmpty || !videos.isEmpty
    }

    /// Converts the input into a single user message ready to send.
    ///
    /// Media blocks are emitted first and the rendered text last, which is the ordering providers
    /// expect for a prompt that refers to an attachment.
    ///
    /// The text block is omitted entirely when the rendered prompt is empty. An input with neither
    /// text nor media therefore produces a message with no content at all, which providers reject.
    ///
    /// - Returns: A message in the user role holding the media followed by the text.
    public func toLLMMessage() -> LLMMessage {
        var contents: [LLMMessage.MessageContent] = []

        // Media first, matching the ordering providers expect.
        contents += images.map { .image($0) }
        contents += audios.map { .audio($0) }
        contents += videos.map { .video($0) }

        // Then the text.
        let text = prompt.render()
        if !text.isEmpty {
            contents.append(.text(text))
        }

        return LLMMessage(role: .user, contents: contents)
    }

    /// Checks every attachment against what the target provider accepts.
    ///
    /// Turns a provider-side rejection into a local error before the request is sent. Only media
    /// is checked — prompt length, token limits, and model-specific restrictions are not.
    ///
    /// - Parameter provider: The provider the input is bound for.
    /// - Throws: `ProviderCompatibilityError` on the first attachment the provider cannot accept.
    public func validate(for provider: ProviderType) throws {
        for image in images {
            try MediaCompatibility.validate(image, for: provider)
        }
        for audio in audios {
            try MediaCompatibility.validate(audio, for: provider)
        }
        for video in videos {
            try MediaCompatibility.validate(video, for: provider)
        }
    }
}
