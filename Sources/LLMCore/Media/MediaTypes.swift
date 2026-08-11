// MediaTypes.swift
// swift-llm-client
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Image Media Type

/// An image format a model can accept as input, with its MIME type and file extension.
///
/// The cases are the union of what the supported providers take, not a set every provider
/// takes. Anthropic and OpenAI accept JPEG, PNG, GIF and WebP; only Gemini accepts HEIC and
/// HEIF. The per-provider matrix lives in `MediaCompatibility` in `LLMProviderCompat`.
///
/// ## Example
/// ```swift
/// let imageType: ImageMediaType = .jpeg
/// print(imageType.fileExtension)  // "jpg"
/// ```
public enum ImageMediaType: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case gif = "image/gif"
    case webp = "image/webp"
    case heic = "image/heic"
    case heif = "image/heif"

    // MARK: - Properties

    /// The lowercase file extension, without a leading dot.
    ///
    /// It is not always the case name: `.jpeg` yields `jpg`. The mapping is lossy in that
    /// direction, since `from(fileExtension:)` folds both `jpg` and `jpeg` back onto `.jpeg`.
    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .gif: return "gif"
        case .webp: return "webp"
        case .heic: return "heic"
        case .heif: return "heif"
        }
    }

    /// The MIME type sent to the provider, which is also the case's raw value and encoded form.
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// Returns the image format for a file extension, or nil when the extension is unknown.
    ///
    /// Matching is case-insensitive, and several extensions collapse onto one case: both `jpg`
    /// and `jpeg` give `.jpeg`.
    ///
    /// - Parameter fileExtension: An extension with no leading dot.
    public static func from(fileExtension: String) -> ImageMediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "gif": return .gif
        case "webp": return .webp
        case "heic": return .heic
        case "heif": return .heif
        default: return nil
        }
    }
}

// MARK: - Audio Media Type

/// An audio format a model can accept as input, with its MIME type and file extension.
///
/// Provider coverage is uneven. Anthropic accepts no audio input at all. OpenAI accepts only
/// WAV and MP3, on audio-capable models, and only from inline data. Gemini accepts every case
/// here. Note that the MP3 case declares `audio/mp3` rather than the registered `audio/mpeg`,
/// so comparing this string against a table of standard MIME types will miss it.
///
/// ## Example
/// ```swift
/// let audioType: AudioMediaType = .wav
/// print(audioType.fileExtension)  // "wav"
/// ```
public enum AudioMediaType: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case wav = "audio/wav"
    case mp3 = "audio/mp3"
    case aac = "audio/aac"
    case flac = "audio/flac"
    case ogg = "audio/ogg"
    case aiff = "audio/aiff"

    // MARK: - Properties

    /// The lowercase file extension, without a leading dot.
    ///
    /// Each case has exactly one extension here even where several map onto it: `.aac` yields
    /// `aac`, never `m4a`, and `.aiff` yields `aiff`, never `aif`.
    public var fileExtension: String {
        switch self {
        case .wav: return "wav"
        case .mp3: return "mp3"
        case .aac: return "aac"
        case .flac: return "flac"
        case .ogg: return "ogg"
        case .aiff: return "aiff"
        }
    }

    /// The MIME type sent to the provider, which is also the case's raw value and encoded form.
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// Returns the audio format for a file extension, or nil when the extension is unknown.
    ///
    /// Matching is case-insensitive and takes an extension with no leading dot. Container
    /// aliases fold onto one case: `m4a` gives `.aac`, `oga` gives `.ogg`, and `aif` gives
    /// `.aiff`.
    ///
    /// - Parameter fileExtension: An extension with no leading dot.
    public static func from(fileExtension: String) -> AudioMediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "wav": return .wav
        case "mp3": return .mp3
        case "aac", "m4a": return .aac
        case "flac": return .flac
        case "ogg", "oga": return .ogg
        case "aiff", "aif": return .aiff
        default: return nil
        }
    }
}

// MARK: - Video Media Type

/// A video format a model can accept as input, with its MIME type and file extension.
///
/// Gemini is the only provider that takes video at all; Anthropic and OpenAI reject every case
/// here, so reaching them means extracting frames and sending those as images instead.
///
/// ## Example
/// ```swift
/// let videoType: VideoMediaType = .mp4
/// print(videoType.fileExtension)  // "mp4"
/// ```
public enum VideoMediaType: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case mp4 = "video/mp4"
    case avi = "video/avi"
    case mov = "video/quicktime"
    case mkv = "video/x-matroska"
    case webm = "video/webm"
    case flv = "video/x-flv"
    case mpeg = "video/mpeg"
    case threegpp = "video/3gpp"
    case wmv = "video/x-ms-wmv"

    // MARK: - Properties

    /// The lowercase file extension, without a leading dot.
    ///
    /// It is not derived from the case name: `.threegpp` yields `3gp` and `.mov` yields `mov`
    /// even though its MIME type says QuickTime.
    public var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .avi: return "avi"
        case .mov: return "mov"
        case .mkv: return "mkv"
        case .webm: return "webm"
        case .flv: return "flv"
        case .mpeg: return "mpeg"
        case .threegpp: return "3gp"
        case .wmv: return "wmv"
        }
    }

    /// The MIME type sent to the provider, which is also the case's raw value and encoded form.
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// Returns the video format for a file extension, or nil when the extension is unknown.
    ///
    /// Matching is case-insensitive and takes an extension with no leading dot. Aliases fold
    /// onto one case: `m4v` gives `.mp4`, `mpg` gives `.mpeg`, and `3gpp` gives `.threegpp`.
    ///
    /// - Parameter fileExtension: An extension with no leading dot.
    public static func from(fileExtension: String) -> VideoMediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "mp4", "m4v": return .mp4
        case "avi": return .avi
        case "mov": return .mov
        case "mkv": return .mkv
        case "webm": return .webm
        case "flv": return .flv
        case "mpeg", "mpg": return .mpeg
        case "3gp", "3gpp": return .threegpp
        case "wmv": return .wmv
        default: return nil
        }
    }
}

// MARK: - Media Type Protocol

/// The shared shape of every media format enumeration.
///
/// Conformance is what lets generic code ask whether a provider accepts a format without
/// knowing which kind of media it is.
///
/// - Important: The generic compatibility check in `LLMProviderCompat` switches over the four
///   formats shipped here and answers `false` for anything else, so a new conforming type is
///   silently reported as unsupported by every provider until that switch learns about it.
public protocol MediaType: RawRepresentable, Sendable, Codable, CaseIterable, Equatable, Hashable where RawValue == String {
    /// The lowercase file extension for this format, with no leading dot.
    var fileExtension: String { get }
    /// The MIME type string handed to the provider.
    var mimeType: String { get }
}

extension ImageMediaType: MediaType {}
extension AudioMediaType: MediaType {}
extension VideoMediaType: MediaType {}
