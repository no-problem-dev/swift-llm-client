// LLMInput.swift
// swift-llm-client
//
// Created by Claude on 2025-12-21.

import Foundation

// MARK: - LLMInput

/// One turn of input to a model: a prompt plus any images, audio, or video that go with it.
///
/// This is the concrete `LLMInputProtocol` implementation every request path accepts. It is
/// expressible by string literal, so a plain prompt needs no ceremony, and it is immutable —
/// the `adding(...)` methods return new values rather than mutating.
///
/// Attaching media does not check whether the target provider supports it. Call
/// `validate(for:)` before sending, or the provider rejects the request at the network boundary.
///
/// ## Examples
///
/// ### Text only
/// ```swift
/// // Straight from a string literal
/// let input: LLMInput = "Hello"
///
/// // Or explicitly
/// let input = LLMInput("Analyze this.")
/// ```
///
/// ### With the SystemPrompt DSL
/// ```swift
/// let input = LLMInput(
///     SystemPrompt {
///         PromptComponent.role("Data analysis expert")
///         PromptComponent.objective("Analyze the sales figures")
///     }
/// )
/// ```
///
/// ### Multimodal
/// ```swift
/// // With an image
/// let input = LLMInput(
///     "Analyze this image.",
///     images: [imageContent]
/// )
///
/// // With audio
/// let input = LLMInput(
///     "Transcribe this recording.",
///     audios: [audioContent]
/// )
///
/// // Several kinds of media at once
/// let input = LLMInput(
///     SystemPrompt {
///         PromptComponent.objective("Analyze the video and the audio")
///     },
///     audios: [audioContent],
///     videos: [videoContent]
/// )
/// ```
public struct LLMInput: LLMInputProtocol, ExpressibleByStringLiteral {
    /// The prompt text, held in the DSL's own type so composed and literal prompts are one thing.
    public let prompt: SystemPrompt

    /// Images to send with the prompt.
    public let images: [ImageContent]

    /// Audio to send with the prompt. Not accepted by every provider.
    public let audios: [AudioContent]

    /// Video to send with the prompt. Accepted by the fewest providers of the three.
    public let videos: [VideoContent]

    // MARK: - Initializers

    /// Creates an input from a composed prompt and any accompanying media.
    ///
    /// - Parameters:
    ///   - prompt: The prompt, typically built with the `SystemPrompt` DSL.
    ///   - images: Images to attach. Empty by default.
    ///   - audios: Audio to attach. Empty by default.
    ///   - videos: Video to attach. Empty by default.
    public init(
        _ prompt: SystemPrompt,
        images: [ImageContent] = [],
        audios: [AudioContent] = [],
        videos: [VideoContent] = []
    ) {
        self.prompt = prompt
        self.images = images
        self.audios = audios
        self.videos = videos
    }

    /// Creates an input from a plain string and any accompanying media.
    ///
    /// - Parameters:
    ///   - text: The prompt text, used verbatim.
    ///   - images: Images to attach. Empty by default.
    ///   - audios: Audio to attach. Empty by default.
    ///   - videos: Video to attach. Empty by default.
    public init(
        _ text: String,
        images: [ImageContent] = [],
        audios: [AudioContent] = [],
        videos: [VideoContent] = []
    ) {
        self.prompt = SystemPrompt(stringLiteral: text)
        self.images = images
        self.audios = audios
        self.videos = videos
    }

    // MARK: - ExpressibleByStringLiteral

    public init(stringLiteral value: String) {
        self.prompt = SystemPrompt(stringLiteral: value)
        self.images = []
        self.audios = []
        self.videos = []
    }
}

// MARK: - Convenience Extensions

extension LLMInput {
    /// Returns a copy with one more image appended.
    ///
    /// - Parameter image: The image to append.
    /// - Returns: A new input; the receiver is unchanged.
    public func adding(image: ImageContent) -> LLMInput {
        LLMInput(
            prompt,
            images: images + [image],
            audios: audios,
            videos: videos
        )
    }

    /// Returns a copy with several more images appended, in order.
    ///
    /// - Parameter newImages: The images to append.
    /// - Returns: A new input; the receiver is unchanged.
    public func adding(images newImages: [ImageContent]) -> LLMInput {
        LLMInput(
            prompt,
            images: images + newImages,
            audios: audios,
            videos: videos
        )
    }

    /// Returns a copy with one more audio clip appended.
    ///
    /// - Parameter audio: The audio to append.
    /// - Returns: A new input; the receiver is unchanged.
    public func adding(audio: AudioContent) -> LLMInput {
        LLMInput(
            prompt,
            images: images,
            audios: audios + [audio],
            videos: videos
        )
    }

    /// Returns a copy with several more audio clips appended, in order.
    ///
    /// - Parameter newAudios: The audio to append.
    /// - Returns: A new input; the receiver is unchanged.
    public func adding(audios newAudios: [AudioContent]) -> LLMInput {
        LLMInput(
            prompt,
            images: images,
            audios: audios + newAudios,
            videos: videos
        )
    }

    /// Returns a copy with one more video appended.
    ///
    /// - Parameter video: The video to append.
    /// - Returns: A new input; the receiver is unchanged.
    public func adding(video: VideoContent) -> LLMInput {
        LLMInput(
            prompt,
            images: images,
            audios: audios,
            videos: videos + [video]
        )
    }

    /// Returns a copy with several more videos appended, in order.
    ///
    /// - Parameter newVideos: The videos to append.
    /// - Returns: A new input; the receiver is unchanged.
    public func adding(videos newVideos: [VideoContent]) -> LLMInput {
        LLMInput(
            prompt,
            images: images,
            audios: audios,
            videos: videos + newVideos
        )
    }
}

