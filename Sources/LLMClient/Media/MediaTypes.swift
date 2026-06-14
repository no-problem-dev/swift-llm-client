// MediaTypes.swift
// swift-llm-structured-outputs
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Image Media Type

/// 画像メディアタイプ
///
/// 画像形式とその MIME タイプ・ファイル拡張子を定義します。
///
/// ## 使用例
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

    /// ファイル拡張子
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

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// ファイル拡張子からメディアタイプを推論
    ///
    /// - Parameter fileExtension: ファイル拡張子（ドットなし）
    /// - Returns: 対応するメディアタイプ、見つからない場合は nil
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

/// 音声メディアタイプ
///
/// 音声形式とその MIME タイプ・ファイル拡張子を定義します。
///
/// ## 使用例
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

    /// ファイル拡張子
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

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// ファイル拡張子からメディアタイプを推論
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

/// 動画メディアタイプ
///
/// 動画形式とその MIME タイプ・ファイル拡張子を定義します。
///
/// ## 使用例
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

    /// ファイル拡張子
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

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// ファイル拡張子からメディアタイプを推論
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

/// メディアタイプ共通プロトコル
///
/// すべてのメディアタイプ列挙型が準拠するプロトコルです。
public protocol MediaType: RawRepresentable, Sendable, Codable, CaseIterable, Equatable, Hashable where RawValue == String {
    /// ファイル拡張子
    var fileExtension: String { get }
    /// MIME タイプ文字列
    var mimeType: String { get }
}

extension ImageMediaType: MediaType {}
extension AudioMediaType: MediaType {}
extension VideoMediaType: MediaType {}
