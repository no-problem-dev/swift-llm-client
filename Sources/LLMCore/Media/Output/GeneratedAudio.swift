// GeneratedAudio.swift
// swift-llm-client
//
// Audio content produced by a model.

import Foundation

// MARK: - GeneratedAudio

/// Audio a model produced, held whole in memory.
///
/// Returned by OpenAI TTS and Gemini TTS. The samples travel with the value, so the audio survives
/// even after the identifier that names it on the provider's side stops resolving.
///
/// ## Provider Differences
/// - **OpenAI TTS**: MP3, Opus, AAC, FLAC, WAV, or PCM, and it stamps an identifier and sometimes
///   an expiry on the result.
/// - **Gemini TTS**: PCM only — Linear16 at 24 kHz, with no container and no header. Writing it to
///   a `.wav` file will not make it playable.
///
/// ## Example
/// ```swift
/// let audio = try await client.generateSpeech(
///     input: "Hello, world!",
///     model: .tts1,
///     voice: .alloy
/// )
///
/// try audio.save(to: URL(fileURLWithPath: "greeting.mp3"))
///
/// // Where AVFoundation is available.
/// if let player = audio.audioPlayer {
///     player.play()
/// }
/// ```
public struct GeneratedAudio: GeneratedMediaProtocol {
    // MARK: - Properties

    /// The audio bytes, already Base64-decoded.
    public let data: Data

    /// The encoding of the bytes, which fixes both the MIME type and the file extension.
    public let format: AudioOutputFormat

    /// The words the audio speaks, when the provider reports them.
    ///
    /// Either the text that was synthesized or, for a transcription round trip, the text
    /// recognized from the audio.
    public let transcript: String?

    /// The provider's identifier for this clip.
    ///
    /// OpenAI stamps one on generated audio; use it to refer back to the clip in a later request
    /// rather than resending the bytes. Other providers leave it nil.
    public let id: String?

    /// When the provider stops honoring the identifier.
    ///
    /// Only the bytes are permanent. Some OpenAI endpoints expire the server-side clip, after which
    /// the identifier no longer resolves — check whether it is expired before reusing it.
    public let expiresAt: Date?

    // MARK: - GeneratedMediaProtocol

    /// The MIME type of the bytes, taken from the format.
    public var mimeType: String { format.mimeType }

    /// The file extension for the bytes, taken from the format.
    public var fileExtension: String { format.fileExtension }

    // MARK: - Initializers

    /// Creates an audio clip from decoded bytes.
    ///
    /// - Parameters:
    ///   - data: Raw audio bytes, not Base64.
    ///   - format: Encoding of the bytes. It is taken on trust and never verified against them.
    ///   - transcript: The words the audio speaks, if known.
    ///   - id: The provider's identifier for the clip.
    ///   - expiresAt: When the provider stops honoring that identifier.
    public init(
        data: Data,
        format: AudioOutputFormat,
        transcript: String? = nil,
        id: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.data = data
        self.format = format
        self.transcript = transcript
        self.id = id
        self.expiresAt = expiresAt
    }

    /// Creates an audio clip by decoding the Base64 payload a provider returned.
    ///
    /// - Parameters:
    ///   - base64String: Base64-encoded audio data, exactly as the API delivered it.
    ///   - format: Encoding of the decoded bytes.
    ///   - transcript: The words the audio speaks, if known.
    ///   - id: The provider's identifier for the clip.
    ///   - expiresAt: When the provider stops honoring that identifier.
    /// - Throws: `GeneratedMediaError.invalidBase64Data` if the string is not valid Base64.
    public init(
        base64String: String,
        format: AudioOutputFormat,
        transcript: String? = nil,
        id: String? = nil,
        expiresAt: Date? = nil
    ) throws {
        guard let data = Data(base64Encoded: base64String) else {
            throw GeneratedMediaError.invalidBase64Data
        }
        self.data = data
        self.format = format
        self.transcript = transcript
        self.id = id
        self.expiresAt = expiresAt
    }

    // MARK: - Metadata

    /// Size of the audio in bytes.
    public var dataSize: Int {
        data.count
    }

    /// The bytes re-encoded as Base64.
    ///
    /// Encoding runs on every access and allocates a string roughly a third larger than the audio.
    /// Store the result if you need it more than once.
    public var base64String: String {
        data.base64EncodedString()
    }

    /// The audio as a data URL, ready to drop into an HTML audio element.
    ///
    /// For example, `data:audio/mp3;base64,SUQzBAA...`. It embeds the whole Base64 payload, so it is
    /// roughly a third larger than the audio itself and is rebuilt on every access.
    public var dataURL: String {
        "data:\(mimeType);base64,\(base64String)"
    }

    /// Whether the provider has stopped honoring this clip's identifier.
    ///
    /// Clips with no expiry never report true. Only the server-side reference lapses; the bytes
    /// held here stay playable either way.
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// A rough playing time in seconds, inferred from the byte count.
    ///
    /// It divides the size by a nominal bit rate for the format and never inspects the audio, so
    /// variable-bit-rate MP3 and FLAC can be off by a wide margin, and PCM assumes Gemini's 24 kHz
    /// 16-bit mono. Despite the optional type it always produces a value. Decode the audio when the
    /// duration has to be exact.
    public var estimatedDuration: TimeInterval? {
        // Nominal bit rates in bits per second, one per format.
        let bytesPerSecond: Double
        switch format {
        case .mp3:
            bytesPerSecond = 128_000 / 8  // 128 kbps
        case .wav:
            bytesPerSecond = 1_411_200 / 8  // 16-bit, 44.1kHz, stereo
        case .opus:
            bytesPerSecond = 64_000 / 8  // 64 kbps (typical)
        case .aac:
            bytesPerSecond = 128_000 / 8  // 128 kbps
        case .flac:
            bytesPerSecond = 1_000_000 / 8  // ~1 Mbps (variable)
        case .pcm:
            bytesPerSecond = 24_000 * 2  // 24kHz, 16-bit mono (Gemini default)
        }
        return Double(dataSize) / bytesPerSecond
    }
}

// MARK: - Codable

extension GeneratedAudio {
    private enum CodingKeys: String, CodingKey {
        case data
        case format
        case transcript
        case id
        case expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(Data.self, forKey: .data)
        self.format = try container.decode(AudioOutputFormat.self, forKey: .format)
        self.transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(format, forKey: .format)
        try container.encodeIfPresent(transcript, forKey: .transcript)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }
}
