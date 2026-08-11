// OutputMediaFormat.swift
// swift-llm-client
//
// Formats a model can return media in.

import Foundation

// MARK: - OutputMediaFormat Protocol

/// An encoding a model can deliver generated media in.
///
/// The output-side counterpart of `MediaType`, which describes media sent *to* a model. Every
/// conforming type stores the MIME type as its raw value, so a case round-trips through the wire
/// format unchanged. Which cases a given provider will actually produce is narrower than the enum;
/// `MediaCompatibility` holds that matrix.
///
/// ## Conforming Types
/// - `ImageOutputFormat`
/// - `AudioOutputFormat`
/// - `VideoOutputFormat`
public protocol OutputMediaFormat: RawRepresentable, Sendable, Codable, CaseIterable, Hashable
    where RawValue == String {
    /// The file extension for this format, with no leading dot.
    var fileExtension: String { get }

    /// The MIME type for this format.
    var mimeType: String { get }
}

// MARK: - ImageOutputFormat

/// An encoding a model can return a generated image in.
///
/// ## Provider Support
/// - **OpenAI (DALL·E / GPT-Image)**: PNG, JPEG, WebP; PNG by default.
/// - **Gemini**: PNG only.
///
/// ## Example
/// ```swift
/// let format: ImageOutputFormat = .png
/// print(format.mimeType)       // "image/png"
/// print(format.fileExtension)  // "png"
/// ```
public enum ImageOutputFormat: String, OutputMediaFormat {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case webp = "image/webp"

    // MARK: - Properties

    /// The file extension for this format, with no leading dot. JPEG shortens to `jpg`.
    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        }
    }

    /// The MIME type for this format, which is also the raw value.
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// Maps a file extension to the format it names.
    ///
    /// Case-insensitive, and both `jpg` and `jpeg` resolve to JPEG.
    ///
    /// - Parameter fileExtension: Extension without a leading dot.
    /// - Returns: The matching format, or nil if the extension names none of them.
    public static func from(fileExtension: String) -> ImageOutputFormat? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        case "webp": return .webp
        default: return nil
        }
    }
}

// MARK: - AudioOutputFormat

/// An encoding a model can return generated audio in.
///
/// PCM is the odd one out: it is raw samples with no container and no header, so a player cannot
/// infer the sample rate from the bytes.
///
/// ## Provider Support
/// - **OpenAI TTS**: MP3, Opus, AAC, FLAC, WAV, PCM.
/// - **Gemini TTS**: PCM only — Linear16 at 24 kHz.
///
/// ## Example
/// ```swift
/// let format: AudioOutputFormat = .mp3
/// print(format.mimeType)       // "audio/mp3"
/// print(format.fileExtension)  // "mp3"
/// ```
public enum AudioOutputFormat: String, OutputMediaFormat {
    case mp3 = "audio/mp3"
    case wav = "audio/wav"
    case opus = "audio/opus"
    case aac = "audio/aac"
    case flac = "audio/flac"
    case pcm = "audio/pcm"

    // MARK: - Properties

    /// The file extension for this format, with no leading dot.
    public var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .wav: return "wav"
        case .opus: return "opus"
        case .aac: return "aac"
        case .flac: return "flac"
        case .pcm: return "pcm"
        }
    }

    /// The MIME type for this format, which is also the raw value.
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// Maps a file extension to the format it names.
    ///
    /// Case-insensitive. It also accepts extensions no case produces: `m4a` resolves to AAC and
    /// `raw` to PCM.
    ///
    /// - Parameter fileExtension: Extension without a leading dot.
    /// - Returns: The matching format, or nil if the extension names none of them.
    public static func from(fileExtension: String) -> AudioOutputFormat? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "mp3": return .mp3
        case "wav": return .wav
        case "opus": return .opus
        case "aac", "m4a": return .aac
        case "flac": return .flac
        case "pcm", "raw": return .pcm
        default: return nil
        }
    }
}

// MARK: - VideoOutputFormat

/// A container a model can return generated video in.
///
/// MP4 is the only case, because it is all any supported provider returns — OpenAI Sora and Gemini
/// Veo alike. The enum exists so callers do not have to hard-code that.
///
/// ## Example
/// ```swift
/// let format: VideoOutputFormat = .mp4
/// print(format.mimeType)       // "video/mp4"
/// print(format.fileExtension)  // "mp4"
/// ```
public enum VideoOutputFormat: String, OutputMediaFormat {
    case mp4 = "video/mp4"

    // MARK: - Properties

    /// The file extension for this format, with no leading dot.
    public var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        }
    }

    /// The MIME type for this format, which is also the raw value.
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// Maps a file extension to the format it names.
    ///
    /// Case-insensitive, and `m4v` resolves to MP4 as well.
    ///
    /// - Parameter fileExtension: Extension without a leading dot.
    /// - Returns: The matching format, or nil if the extension names none of them.
    public static func from(fileExtension: String) -> VideoOutputFormat? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "mp4", "m4v": return .mp4
        default: return nil
        }
    }
}
