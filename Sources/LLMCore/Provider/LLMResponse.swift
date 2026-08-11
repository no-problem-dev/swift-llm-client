// LLMResponse.swift
// swift-llm-client

import Foundation

// MARK: - LLMResponse

/// A reply from a model, in the same shape whichever provider produced it.
public struct LLMResponse: Sendable {
    /// Content blocks in the order the model produced them.
    public let content: [ContentBlock]

    /// Model that answered, as the provider named it, which can be more exact than the alias asked for.
    public let model: String

    /// Token counts for the request, normalized so the input figure includes cached tokens.
    public let usage: TokenUsage

    /// Why generation stopped. Nil when the provider did not say.
    public let stopReason: StopReason?

    public init(
        content: [ContentBlock],
        model: String,
        usage: TokenUsage,
        stopReason: StopReason? = nil
    ) {
        self.content = content
        self.model = model
        self.usage = usage
        self.stopReason = stopReason
    }

    // MARK: - Convenience Accessors

    /// The text blocks joined into one string, with tool calls, media and thinking left out.
    public var text: String {
        content.compactMap { $0.text }.joined()
    }

    /// The extended-thinking blocks joined into one string, without their signatures.
    public var thinkingText: String {
        content.compactMap { $0.thinkingText }.joined()
    }

    /// Images the model produced, empty when it produced none.
    public var generatedImages: [GeneratedImage] {
        content.compactMap { $0.generatedImage }
    }

    /// The first image the model produced, or nil when it produced none.
    public var firstGeneratedImage: GeneratedImage? {
        generatedImages.first
    }

    /// Audio the model produced, empty when it produced none.
    public var generatedAudio: [GeneratedAudio] {
        content.compactMap { $0.generatedAudio }
    }

    /// The first audio the model produced, or nil when it produced none.
    public var firstGeneratedAudio: GeneratedAudio? {
        generatedAudio.first
    }

    public var hasImages: Bool {
        content.contains { $0.generatedImage != nil }
    }

    public var hasAudio: Bool {
        content.contains { $0.generatedAudio != nil }
    }

    /// Whether the response carries an image or audio.
    public var hasMedia: Bool {
        hasImages || hasAudio
    }

    /// One block of content in a response.
    ///
    /// ## Kinds
    /// - `text`: text the model wrote
    /// - `toolUse`: a tool the model wants run before it can continue
    /// - `image`: an image produced inline, as Gemini does
    /// - `audio`: speech produced inline, as text-to-speech models do
    public enum ContentBlock: Sendable {
        case text(String)

        /// A tool the model wants run. Answer it with a result quoting the same identifier before
        /// asking for another turn.
        case toolUse(id: String, name: String, input: Data)

        /// An image returned inline in the response, as with Gemini's multimodal output.
        case image(GeneratedImage)

        /// Speech returned inline in the response, as with text-to-speech models.
        case audio(GeneratedAudio)

        /// Reasoning the model produced with extended thinking.
        ///
        /// The signature identifies the block when it is handed back on a later request.
        case thinking(text: String, signature: String?)

        // MARK: - Convenience Accessors

        /// The text of the block, or nil when it is not a text block.
        public var text: String? {
            if case .text(let value) = self {
                return value
            }
            return nil
        }

        /// The image of the block, or nil when it is not an image block.
        public var generatedImage: GeneratedImage? {
            if case .image(let image) = self {
                return image
            }
            return nil
        }

        /// The audio of the block, or nil when it is not an audio block.
        public var generatedAudio: GeneratedAudio? {
            if case .audio(let audio) = self {
                return audio
            }
            return nil
        }

        /// The thinking text of the block, or nil when it is not a thinking block.
        public var thinkingText: String? {
            if case .thinking(let text, _) = self {
                return text
            }
            return nil
        }

        /// Decodes the arguments of a tool call into a value.
        ///
        /// Returns nil when the block is not a tool call, and throws when the arguments do not fit
        /// the requested type. Keys are read from snake case, which is how providers emit them.
        public func toolInput<T: Decodable>(as type: T.Type) throws -> T? {
            guard case .toolUse(_, _, let data) = self else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        }
    }

    /// Why the model stopped generating.
    public enum StopReason: String, Sendable {
        /// The model finished what it had to say.
        case endTurn = "end_turn"
        /// The output cap was reached, so the text is cut off mid-answer.
        case maxTokens = "max_tokens"
        /// A configured stop sequence came up.
        case stopSequence = "stop_sequence"
        /// The model is waiting for tool results before it can go on.
        case toolUse = "tool_use"
        /// The conversation no longer fits the model's context window.
        case modelContextWindowExceeded = "model_context_window_exceeded"
    }
}

// TokenUsage lives in Cost/TokenUsage.swift.

