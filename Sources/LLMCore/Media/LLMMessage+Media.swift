// LLMMessage+Media.swift
// swift-llm-client
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - LLMMessage Media Extensions

extension LLMMessage {

    // MARK: - Image messages

    /// Builds a user message carrying one image and a line of text.
    ///
    /// The image is placed before the text in the content list. That ordering is deliberate:
    /// models attend to a question asked after the image more reliably than to one asked
    /// before it. Build the content list yourself if you need the other order.
    ///
    /// ## Example
    /// ```swift
    /// let imageData = try Data(contentsOf: imageURL)
    /// let message = LLMMessage.user(
    ///     "What is in this image?",
    ///     image: .base64(imageData, mediaType: .jpeg)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: The prompt, placed after the image.
    ///   - image: The image to attach.
    public static func user(_ text: String, image: ImageContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.image(image), .text(text)])
    }

    /// Builds a user message carrying several images and a line of text.
    ///
    /// The images keep their given order and all precede the text. Each one is billed as input
    /// tokens in its own right, so the cost of this message grows with the number of images,
    /// and providers cap how many a single request may carry.
    ///
    /// ## Example
    /// ```swift
    /// let images = [
    ///     ImageContent.base64(image1Data, mediaType: .jpeg),
    ///     ImageContent.base64(image2Data, mediaType: .png)
    /// ]
    /// let message = LLMMessage.user("Compare these images.", images: images)
    /// ```
    ///
    /// - Parameters:
    ///   - text: The prompt, placed after every image.
    ///   - images: The images to attach, in the order the model should see them.
    public static func user(_ text: String, images: [ImageContent]) -> LLMMessage {
        var contents: [MessageContent] = images.map { .image($0) }
        contents.append(.text(text))
        return LLMMessage(role: .user, contents: contents)
    }

    // MARK: - Audio messages

    /// Builds a user message carrying an audio clip and a line of text.
    ///
    /// Use it to have a recording transcribed or described. The audio precedes the text, and
    /// Anthropic rejects the message outright since it takes no audio input.
    ///
    /// ## Example
    /// ```swift
    /// let audioData = try Data(contentsOf: audioURL)
    /// let message = LLMMessage.user(
    ///     "Transcribe this recording.",
    ///     audio: .base64(audioData, mediaType: .wav)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: The prompt, placed after the audio.
    ///   - audio: The audio to attach.
    public static func user(_ text: String, audio: AudioContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.audio(audio), .text(text)])
    }

    // MARK: - Video messages

    /// Builds a user message carrying a video and a line of text.
    ///
    /// The video precedes the text. Gemini is the only provider that accepts video, and a file
    /// API reference is usually the practical source given how large video gets.
    ///
    /// ## Example
    /// ```swift
    /// let message = LLMMessage.user(
    ///     "Describe what happens in this video.",
    ///     video: .fileReference("files/video123", mediaType: .mp4)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: The prompt, placed after the video.
    ///   - video: The video to attach.
    public static func user(_ text: String, video: VideoContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.video(video), .text(text)])
    }

    // MARK: - Document messages

    /// Builds a user message carrying a document and a line of text.
    ///
    /// Use it to summarize, analyse or extract from a PDF or text file. The document precedes
    /// the text, and every provider accepts both document formats — but a PDF is billed per
    /// page, so a long one dominates the token cost of the request.
    ///
    /// ## Example
    /// ```swift
    /// let document = try DocumentContent.file(at: "/path/to/report.pdf")
    /// let message = LLMMessage.user(
    ///     "Summarize this PDF.",
    ///     document: document
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: The prompt, placed after the document.
    ///   - document: The document to attach.
    public static func user(_ text: String, document: DocumentContent) -> LLMMessage {
        LLMMessage(role: .user, contents: [.document(document), .text(text)])
    }

    /// Builds a user message carrying several documents and a line of text.
    ///
    /// The documents keep their given order and all precede the text. Give each one a title, or
    /// the model has no reliable way to say which document an answer came from.
    ///
    /// - Parameters:
    ///   - text: The prompt, placed after every document.
    ///   - documents: The documents to attach, in the order the model should see them.
    public static func user(_ text: String, documents: [DocumentContent]) -> LLMMessage {
        var contents: [MessageContent] = documents.map { .document($0) }
        contents.append(.text(text))
        return LLMMessage(role: .user, contents: contents)
    }

    // MARK: - Mixed messages

    /// Builds a user message from an explicit content list.
    ///
    /// The escape hatch from the typed constructors: it mixes media kinds and is the only way
    /// to control ordering, since the array is used exactly as given rather than being
    /// rearranged to put media first.
    ///
    /// ## Example
    /// ```swift
    /// let message = LLMMessage.user(contents: [
    ///     .text("Describe the image and the recording below."),
    ///     .image(imageContent),
    ///     .audio(audioContent)
    /// ])
    /// ```
    ///
    /// - Parameter contents: The message parts, in the order the model should see them.
    public static func user(contents: [MessageContent]) -> LLMMessage {
        LLMMessage(role: .user, contents: contents)
    }

    // MARK: - Convenience Properties

    /// Every image in the message, in content order.
    ///
    /// Empty when there are none, so it never distinguishes "no images" from "not a media
    /// message". The array is rebuilt on each access.
    public var images: [ImageContent] {
        contents.compactMap { content in
            if case .image(let image) = content { return image }
            return nil
        }
    }

    /// Every audio clip in the message, in content order.
    ///
    /// Useful before routing: a non-empty result means the message cannot go to Anthropic.
    public var audios: [AudioContent] {
        contents.compactMap { content in
            if case .audio(let audio) = content { return audio }
            return nil
        }
    }

    /// Every video in the message, in content order.
    ///
    /// Useful before routing: a non-empty result means the message can only go to Gemini.
    public var videos: [VideoContent] {
        contents.compactMap { content in
            if case .video(let video) = content { return video }
            return nil
        }
    }

    /// Every document in the message, in content order.
    public var documents: [DocumentContent] {
        contents.compactMap { content in
            if case .document(let document) = content { return document }
            return nil
        }
    }

    /// Whether the message carries an image, audio clip, video or document.
    ///
    /// A cheap first filter before deciding whether provider compatibility needs checking at
    /// all. Tool calls, tool results and thinking blocks do not count as media.
    public var hasMediaContent: Bool {
        contents.contains { content in
            switch content {
            case .image, .audio, .video, .document: return true
            default: return false
            }
        }
    }

    /// Whether the message carries at least one image.
    ///
    /// Cheaper than building the image array when only the answer matters.
    public var hasImage: Bool {
        contents.contains { if case .image = $0 { return true }; return false }
    }

    /// Whether the message carries at least one audio clip, which rules out Anthropic.
    public var hasAudio: Bool {
        contents.contains { if case .audio = $0 { return true }; return false }
    }

    /// Whether the message carries at least one video, which narrows delivery to Gemini.
    public var hasVideo: Bool {
        contents.contains { if case .video = $0 { return true }; return false }
    }

    /// Whether the message carries at least one document.
    public var hasDocument: Bool {
        contents.contains { if case .document = $0 { return true }; return false }
    }
}
