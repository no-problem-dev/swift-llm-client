// AudioGeneration.swift
// swift-llm-client
//
// Protocols and supporting types for speech generation (TTS).

import Foundation

// MARK: - SpeechGenerationCapable Protocol

/// A client that can synthesize speech from text.
///
/// The samples travel with the result rather than living on the provider's servers, so the audio
/// outlives any identifier stamped on it. Which encodings and voices are available differs by
/// provider.
///
/// ## Example
/// ```swift
/// // Generating speech with the OpenAI client.
/// let client = OpenAIClient(apiKey: "sk-...")
/// let audio = try await client.generateSpeech(
///     input: "Hello, world!",
///     model: .tts1,
///     voice: .alloy
/// )
/// try audio.save(to: URL(fileURLWithPath: "greeting.mp3"))
/// ```
public protocol SpeechGenerationCapable<SpeechModel>: Sendable {
    /// The catalog of speech models this client accepts.
    associatedtype SpeechModel: Sendable

    /// The set of voices those models can speak in.
    associatedtype Voice: Sendable

    /// Synthesizes speech and returns the audio.
    ///
    /// - Parameters:
    ///   - input: The text to speak.
    ///   - model: The speech model to call.
    ///   - voice: The voice to speak in.
    ///   - speed: Playback rate, from 0.25 to 4.0. Anything outside that range is rejected.
    ///   - format: Encoding of the returned bytes. Nil leaves the choice to the provider.
    /// - Returns: The generated audio.
    /// - Throws: `LLMError` or `SpeechGenerationError`.
    func generateSpeech(
        input: LLMInput,
        model: SpeechModel,
        voice: Voice,
        speed: Double?,
        format: AudioOutputFormat?
    ) async throws -> GeneratedAudio
}

// MARK: - Default Implementations

extension SpeechGenerationCapable {
    /// Synthesizes speech, filling in defaults for the playback rate and the output encoding.
    ///
    /// It exists only to supply those defaults and forwards to the conforming type's own
    /// implementation.
    public func generateSpeech(
        input: LLMInput,
        model: SpeechModel,
        voice: Voice,
        speed: Double? = nil,
        format: AudioOutputFormat? = nil
    ) async throws -> GeneratedAudio {
        try await generateSpeech(
            input: input,
            model: model,
            voice: voice,
            speed: speed,
            format: format
        )
    }
}

// MARK: - OpenAI TTS Models

/// The OpenAI text-to-speech models.
public enum OpenAITTSModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// TTS-1. Standard quality, and the lower-latency choice.
    case tts1 = "tts-1"
    /// TTS-1 HD. Higher quality, at the cost of latency.
    case tts1HD = "tts-1-hd"

    /// The identifier sent to the API.
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tts1: return "TTS-1"
        case .tts1HD: return "TTS-1 HD"
        }
    }

    /// The encodings OpenAI returns speech in: MP3, Opus, AAC, FLAC, WAV, and PCM.
    public var supportedFormats: [AudioOutputFormat] {
        MediaCompatibility.audioOutputFormats(for: .openai)
    }
}

// MARK: - OpenAI TTS Voices

/// The voices OpenAI's text-to-speech models can speak in.
public enum OpenAIVoice: String, Sendable, Codable, CaseIterable, Equatable {
    /// Alloy, a neutral voice.
    case alloy
    /// Echo, a masculine voice.
    case echo
    /// Fable, a masculine voice with a British accent.
    case fable
    /// Onyx, a deep masculine voice.
    case onyx
    /// Nova, a feminine voice.
    case nova
    /// Shimmer, a soft feminine voice.
    case shimmer

    /// The identifier sent to the API.
    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Gemini TTS Models

/// The Gemini text-to-speech models.
public enum GeminiTTSModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// Gemini TTS, which is served from a preview endpoint.
    case geminiTTS = "gemini-tts-preview"

    /// The identifier sent to the API.
    public var id: String { rawValue }

    public var displayName: String {
        "Gemini TTS"
    }

    /// The encodings Gemini returns speech in, which is raw PCM and nothing else.
    public var supportedFormats: [AudioOutputFormat] {
        MediaCompatibility.audioOutputFormats(for: .gemini)
    }
}

// MARK: - SpeechGenerationError

/// Failures specific to speech generation, as opposed to transport or decoding errors.
public enum SpeechGenerationError: Error, Sendable, LocalizedError {
    /// The text is longer than the model will speak in one call.
    case textTooLong(length: Int, maximum: Int)
    /// There was nothing to speak.
    case emptyText
    /// The playback rate falls outside the accepted range of 0.25 to 4.0.
    case invalidSpeed(Double)
    /// The requested output encoding is not one the model returns.
    case unsupportedFormat(AudioOutputFormat, model: String)
    /// The provider generates no speech at all.
    case notSupportedByProvider(String)

    public var errorDescription: String? {
        switch self {
        case .textTooLong(let length, let maximum):
            return "Text length (\(length)) exceeds maximum (\(maximum))"
        case .emptyText:
            return "Text cannot be empty"
        case .invalidSpeed(let speed):
            return "Speed \(speed) is not valid. Must be between 0.25 and 4.0"
        case .unsupportedFormat(let format, let model):
            return "Format \(format.rawValue) is not supported by \(model)"
        case .notSupportedByProvider(let provider):
            return "Speech generation is not supported by \(provider)"
        }
    }
}
