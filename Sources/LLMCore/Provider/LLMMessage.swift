// LLMMessage.swift
// swift-llm-client

import Foundation

// MARK: - LLMMessage

/// One message in a conversation with a model.
///
/// Carries plain text as well as tool calls and tool results.
///
/// ## Example
///
/// ```swift
/// // Text messages
/// let userMessage = LLMMessage.user("What's the weather in Tokyo?")
/// let assistantMessage = LLMMessage.assistant("It's sunny in Tokyo.")
///
/// // A tool call (the assistant's reply)
/// let toolCallMessage = LLMMessage.toolUse(
///     id: "call_123",
///     name: "get_weather",
///     input: jsonData
/// )
///
/// // A tool result (sent back as a user message)
/// let toolResultMessage = LLMMessage.toolResult(
///     toolCallId: "call_123",
///     name: "get_weather",
///     content: "Sunny, 25 degrees"
/// )
/// ```
public struct LLMMessage: Sendable, Codable {
    public let role: Role

    /// Blocks the message is made of; one message can mix text, media and tool blocks.
    public let contents: [MessageContent]

    /// The two ends of a conversation.
    ///
    /// There is no system role: a system prompt travels as its own field of the request, not as a
    /// message. Tool results are sent as a user message.
    public enum Role: String, Sendable, Codable {
        case user
        case assistant
    }

    /// One block of content inside a message.
    public enum MessageContent: Sendable, Equatable, Codable {
        // MARK: - Text and tools

        case text(String)

        /// A tool call the assistant produced.
        case toolUse(id: String, name: String, input: Data)

        /// The outcome of running a tool, sent back in answer to a tool call.
        /// - Parameters:
        ///   - toolCallId: Identifier of the call this answers; providers match the pair by it.
        ///   - name: Tool name, which the Gemini API requires.
        ///   - content: The outcome, successful or failed.
        case toolResult(toolCallId: String, name: String, content: ToolResultContent)

        // MARK: - Media input

        /// An image.
        ///
        /// Support:
        /// - Anthropic: yes (JPEG, PNG, GIF, WebP)
        /// - OpenAI: yes (JPEG, PNG, GIF, WebP)
        /// - Gemini: yes (JPEG, PNG, GIF, WebP, HEIC, HEIF)
        case image(ImageContent)

        /// A sound file.
        ///
        /// Support:
        /// - Anthropic: no
        /// - OpenAI: yes (WAV, MP3), on gpt-4o-audio-preview only
        /// - Gemini: yes (WAV, MP3, AAC, FLAC, OGG, AIFF)
        case audio(AudioContent)

        /// A video.
        ///
        /// Support:
        /// - Anthropic: no
        /// - OpenAI: no; the video has to be split into frames first
        /// - Gemini: yes (MP4, AVI, MOV, MKV, WebM, FLV, MPEG, 3GP, WMV)
        case video(VideoContent)

        /// A document.
        ///
        /// Support:
        /// - Anthropic: yes (PDF, text)
        /// - OpenAI: yes (PDF, text)
        /// - Gemini: yes (PDF, text)
        case document(DocumentContent)

        /// Reasoning the model produced with extended thinking.
        ///
        /// Keeps Claude's thinking in the conversation history. The signature identifies the block
        /// so it can be handed back on a later request.
        case thinking(text: String, signature: String?)

        // MARK: - Codable

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case id
            case name
            case input
            case toolCallId
            case content
            case imageContent
            case audioContent
            case videoContent
            case documentContent
            case signature
        }

        private enum ContentType: String, Codable {
            case text
            case toolUse
            case toolResult
            case image
            case audio
            case video
            case document
            case thinking
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(ContentType.self, forKey: .type)

            switch type {
            case .text:
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case .toolUse:
                let id = try container.decode(String.self, forKey: .id)
                let name = try container.decode(String.self, forKey: .name)
                let input = try container.decode(Data.self, forKey: .input)
                self = .toolUse(id: id, name: name, input: input)
            case .toolResult:
                let toolCallId = try container.decode(String.self, forKey: .toolCallId)
                let name = try container.decode(String.self, forKey: .name)
                let content = try container.decode(ToolResultContent.self, forKey: .content)
                self = .toolResult(toolCallId: toolCallId, name: name, content: content)
            case .image:
                let imageContent = try container.decode(ImageContent.self, forKey: .imageContent)
                self = .image(imageContent)
            case .audio:
                let audioContent = try container.decode(AudioContent.self, forKey: .audioContent)
                self = .audio(audioContent)
            case .video:
                let videoContent = try container.decode(VideoContent.self, forKey: .videoContent)
                self = .video(videoContent)
            case .document:
                let documentContent = try container.decode(DocumentContent.self, forKey: .documentContent)
                self = .document(documentContent)
            case .thinking:
                let text = try container.decode(String.self, forKey: .text)
                let signature = try container.decodeIfPresent(String.self, forKey: .signature)
                self = .thinking(text: text, signature: signature)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .text(let text):
                try container.encode(ContentType.text, forKey: .type)
                try container.encode(text, forKey: .text)
            case .toolUse(let id, let name, let input):
                try container.encode(ContentType.toolUse, forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
                try container.encode(input, forKey: .input)
            case .toolResult(let toolCallId, let name, let content):
                try container.encode(ContentType.toolResult, forKey: .type)
                try container.encode(toolCallId, forKey: .toolCallId)
                try container.encode(name, forKey: .name)
                try container.encode(content, forKey: .content)
            case .image(let imageContent):
                try container.encode(ContentType.image, forKey: .type)
                try container.encode(imageContent, forKey: .imageContent)
            case .audio(let audioContent):
                try container.encode(ContentType.audio, forKey: .type)
                try container.encode(audioContent, forKey: .audioContent)
            case .video(let videoContent):
                try container.encode(ContentType.video, forKey: .type)
                try container.encode(videoContent, forKey: .videoContent)
            case .document(let documentContent):
                try container.encode(ContentType.document, forKey: .type)
                try container.encode(documentContent, forKey: .documentContent)
            case .thinking(let text, let signature):
                try container.encode(ContentType.thinking, forKey: .type)
                try container.encode(text, forKey: .text)
                try container.encodeIfPresent(signature, forKey: .signature)
            }
        }
    }

    // MARK: - Initializers

    /// Creates a message from content blocks, keeping them in the order given.
    public init(role: Role, contents: [MessageContent]) {
        self.role = role
        self.contents = contents
    }

    /// Creates a message holding a single text block.
    public init(role: Role, content: String) {
        self.role = role
        self.contents = [.text(content)]
    }

    // MARK: - Convenience Properties

    /// The text blocks of the message joined into one string.
    ///
    /// Tool and media blocks are skipped, so a message that carries only a tool call reads as empty
    /// here rather than as missing text.
    public var content: String {
        contents.compactMap { content in
            if case .text(let text) = content {
                return text
            }
            return nil
        }.joined()
    }

    public var hasToolUse: Bool {
        contents.contains { content in
            if case .toolUse = content { return true }
            return false
        }
    }

    public var hasToolResult: Bool {
        contents.contains { content in
            if case .toolResult = content { return true }
            return false
        }
    }

    /// Tool calls in the message, in the order the model emitted them.
    public var toolUses: [(id: String, name: String, input: Data)] {
        contents.compactMap { content in
            if case .toolUse(let id, let name, let input) = content {
                return (id, name, input)
            }
            return nil
        }
    }

    /// Tool results in the message, in the order they were put in.
    public var toolResults: [(toolCallId: String, name: String, content: ToolResultContent)] {
        contents.compactMap { content in
            if case .toolResult(let id, let name, let resultContent) = content {
                return (id, name, resultContent)
            }
            return nil
        }
    }

    // MARK: - Factory Methods

    /// Creates a user message holding a single text block.
    public static func user(_ content: String) -> LLMMessage {
        LLMMessage(role: .user, content: content)
    }

    /// Creates an assistant message holding a single text block.
    public static func assistant(_ content: String) -> LLMMessage {
        LLMMessage(role: .assistant, content: content)
    }

    /// Creates the assistant message that records a tool call.
    ///
    /// It has to go into the history before the matching result, since a provider refuses a tool
    /// result that answers nothing. Usually built from a response rather than by hand.
    ///
    /// - Parameters:
    ///   - id: Identifier of the call, which the result has to quote back.
    ///   - name: Tool name.
    ///   - input: Tool arguments, as JSON.
    public static func toolUse(id: String, name: String, input: Data) -> LLMMessage {
        LLMMessage(role: .assistant, contents: [.toolUse(id: id, name: name, input: input)])
    }

    /// Creates one assistant message recording several tool calls the model asked for at once.
    ///
    /// - Parameter toolCalls: The calls, kept in the order given.
    public static func toolUses(_ toolCalls: [(id: String, name: String, input: Data)]) -> LLMMessage {
        let contents = toolCalls.map { MessageContent.toolUse(id: $0.id, name: $0.name, input: $0.input) }
        return LLMMessage(role: .assistant, contents: contents)
    }

    /// Creates the user message that returns a successful tool result to the model.
    ///
    /// It takes the user role because that is how providers expect tool output to come back.
    ///
    /// - Parameters:
    ///   - toolCallId: Identifier of the call this answers.
    ///   - name: Tool name.
    ///   - content: What the tool produced.
    public static func toolResult(
        toolCallId: String,
        name: String,
        content: String
    ) -> LLMMessage {
        LLMMessage(role: .user, contents: [.toolResult(toolCallId: toolCallId, name: name, content: .success(content))])
    }

    /// Creates the user message that tells the model a tool failed.
    ///
    /// The failure is data the model reads and can react to, so send it rather than dropping the
    /// turn: a call left unanswered makes the next request invalid.
    ///
    /// - Parameters:
    ///   - toolCallId: Identifier of the call this answers.
    ///   - name: Tool name.
    ///   - error: Message describing the failure, written for the model to read.
    public static func toolError(
        toolCallId: String,
        name: String,
        error: String
    ) -> LLMMessage {
        LLMMessage(role: .user, contents: [.toolResult(toolCallId: toolCallId, name: name, content: .failure(error))])
    }

    /// Creates one user message returning the results of several tool calls at once.
    ///
    /// - Parameter results: The results, one per outstanding call.
    public static func toolResults(_ results: [(toolCallId: String, name: String, content: ToolResultContent)]) -> LLMMessage {
        let contents = results.map {
            MessageContent.toolResult(toolCallId: $0.toolCallId, name: $0.name, content: $0.content)
        }
        return LLMMessage(role: .user, contents: contents)
    }
}

