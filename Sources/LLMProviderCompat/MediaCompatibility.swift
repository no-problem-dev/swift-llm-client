// MediaCompatibility.swift
// swift-llm-client
//
// Created by Claude on 2025-12-20.

import Foundation
import LLMCore

// MARK: - Provider Capabilities Protocol

/// プロバイダーの機能・能力を定義するプロトコル
public protocol ProviderCapabilities: Sendable {
    /// プロバイダーの表示名
    var displayName: String { get }
    /// 指定されたメディアタイプをサポートしているか
    func supports<T: MediaType>(_ mediaType: T) -> Bool
}

// MARK: - Provider Type

/// プロバイダー識別子
///
/// LLMプロバイダーを識別するための列挙型です。
/// メディア機能のサポート確認やエラーメッセージに使用されます。
public enum ProviderType: String, Sendable, Codable, ProviderCapabilities {
    case anthropic
    case openai
    case gemini

    /// プロバイダーの表示名
    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        }
    }

    /// 指定されたメディアタイプをサポートしているか
    public func supports<T: MediaType>(_ mediaType: T) -> Bool {
        MediaCompatibility.isSupported(mediaType, by: self)
    }
}

// MARK: - Provider Compatibility Error

/// プロバイダー互換性エラー
///
/// メディアコンテンツが対象プロバイダーでサポートされない場合に投げられます。
public enum ProviderCompatibilityError: Error, Sendable, Equatable, LocalizedError {
    /// プロバイダーが機能をサポートしていない
    case notSupportedByProvider(feature: String, provider: ProviderType)

    /// メディアタイプがプロバイダーでサポートされていない
    case unsupportedMediaType(mimeType: String, provider: ProviderType)

    public var errorDescription: String? {
        switch self {
        case .notSupportedByProvider(let feature, let provider):
            return "\(feature) is not supported by \(provider.displayName)"
        case .unsupportedMediaType(let mimeType, let provider):
            return "Media type '\(mimeType)' is not supported by \(provider.displayName)"
        }
    }
}

// MARK: - Media Compatibility Matrix

/// メディアタイプとプロバイダーの互換性マトリクス
///
/// 「どのプロバイダーが何を許すか」というプロバイダー固有の知識を集約します。
/// ドメイン値型（`ImageContent` 等）はこの知識を持たず、検証はここに委譲されます。
public enum MediaCompatibility {

    // MARK: - Image Type Compatibility

    /// 全プロバイダーで共通サポートされる画像タイプ
    public static var universalImageTypes: [ImageMediaType] {
        [.jpeg, .png, .gif, .webp]
    }

    /// Gemini 専用の画像タイプ
    public static var geminiOnlyImageTypes: [ImageMediaType] {
        [.heic, .heif]
    }

    /// 指定された画像タイプがプロバイダーでサポートされるか
    public static func isSupported(_ type: ImageMediaType, by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic, .openai:
            return universalImageTypes.contains(type)
        case .gemini:
            return true
        }
    }

    // MARK: - Audio Type Compatibility

    /// OpenAI Chat Completions でサポートされる音声タイプ
    public static var openaiChatAudioTypes: [AudioMediaType] {
        [.wav, .mp3]
    }

    /// Gemini でサポートされる音声タイプ
    public static var geminiAudioTypes: [AudioMediaType] {
        AudioMediaType.allCases
    }

    /// 指定された音声タイプがプロバイダーでサポートされるか
    public static func isSupported(_ type: AudioMediaType, by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic:
            return false
        case .openai:
            return openaiChatAudioTypes.contains(type)
        case .gemini:
            return true
        }
    }

    // MARK: - Video Type Compatibility

    /// 指定された動画タイプがプロバイダーでサポートされるか
    public static func isSupported(_ type: VideoMediaType, by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic, .openai:
            return false
        case .gemini:
            return true
        }
    }

    // MARK: - Document Type Compatibility

    /// 指定されたドキュメントタイプがプロバイダーでサポートされるか
    public static func isSupported(_ type: DocumentMediaType, by provider: ProviderType) -> Bool {
        switch provider {
        case .anthropic, .openai, .gemini:
            return true
        }
    }

    // MARK: - Image Output Format Compatibility

    /// 指定されたプロバイダーがサポートする画像出力フォーマット
    public static func imageOutputFormats(for provider: ProviderType) -> [ImageOutputFormat] {
        switch provider {
        case .anthropic:
            return []
        case .openai:
            return [.png, .jpeg, .webp]
        case .gemini:
            return [.png]
        }
    }

    /// 指定された画像出力フォーマットがプロバイダーでサポートされるか
    public static func isSupported(_ format: ImageOutputFormat, by provider: ProviderType) -> Bool {
        imageOutputFormats(for: provider).contains(format)
    }

    // MARK: - Audio Output Format Compatibility

    /// 指定されたプロバイダーがサポートする音声出力フォーマット
    public static func audioOutputFormats(for provider: ProviderType) -> [AudioOutputFormat] {
        switch provider {
        case .anthropic:
            return []
        case .openai:
            return [.mp3, .opus, .aac, .flac, .wav, .pcm]
        case .gemini:
            return [.pcm]
        }
    }

    /// 指定された音声出力フォーマットがプロバイダーでサポートされるか
    public static func isSupported(_ format: AudioOutputFormat, by provider: ProviderType) -> Bool {
        audioOutputFormats(for: provider).contains(format)
    }

    // MARK: - Video Output Format Compatibility

    /// 指定されたプロバイダーがサポートする動画出力フォーマット
    public static func videoOutputFormats(for provider: ProviderType) -> [VideoOutputFormat] {
        switch provider {
        case .anthropic:
            return []
        case .openai:
            return [.mp4]
        case .gemini:
            return [.mp4]
        }
    }

    /// 指定された動画出力フォーマットがプロバイダーでサポートされるか
    public static func isSupported(_ format: VideoOutputFormat, by provider: ProviderType) -> Bool {
        videoOutputFormats(for: provider).contains(format)
    }

    // MARK: - Generic Media Type Compatibility

    /// 指定されたメディアタイプがプロバイダーでサポートされるか
    public static func isSupported<T: MediaType>(_ type: T, by provider: ProviderType) -> Bool {
        switch type {
        case let image as ImageMediaType:
            return isSupported(image, by: provider)
        case let audio as AudioMediaType:
            return isSupported(audio, by: provider)
        case let video as VideoMediaType:
            return isSupported(video, by: provider)
        case let document as DocumentMediaType:
            return isSupported(document, by: provider)
        default:
            return false
        }
    }

    // MARK: - Media Type Validation

    /// メディアタイプのプロバイダーサポートを検証
    ///
    /// - Throws: `ProviderCompatibilityError.unsupportedMediaType` 未サポート時
    public static func validateSupport<T: MediaType>(_ type: T, for provider: ProviderType) throws {
        if !isSupported(type, by: provider) {
            throw ProviderCompatibilityError.unsupportedMediaType(
                mimeType: type.mimeType,
                provider: provider
            )
        }
    }

    // MARK: - Content Validation

    /// 画像コンテンツのプロバイダー互換性を検証
    ///
    /// - Throws: `ProviderCompatibilityError` 互換性がない場合
    public static func validate(_ image: ImageContent, for provider: ProviderType) throws {
        try validateSupport(image.mediaType, for: provider)

        if image.source.isFileReference && provider == .anthropic {
            throw ProviderCompatibilityError.notSupportedByProvider(
                feature: "File reference",
                provider: provider
            )
        }
    }

    /// 音声コンテンツのプロバイダー互換性を検証
    ///
    /// - Throws: `ProviderCompatibilityError` 互換性がない場合
    public static func validate(_ audio: AudioContent, for provider: ProviderType) throws {
        if provider == .anthropic {
            throw ProviderCompatibilityError.notSupportedByProvider(
                feature: "Audio input",
                provider: provider
            )
        }

        try validateSupport(audio.mediaType, for: provider)

        if provider == .openai && !audio.source.isBase64 {
            throw ProviderCompatibilityError.notSupportedByProvider(
                feature: "Audio from URL (use base64)",
                provider: provider
            )
        }
    }

    /// 動画コンテンツのプロバイダー互換性を検証
    ///
    /// - Throws: `ProviderCompatibilityError` 互換性がない場合
    public static func validate(_ video: VideoContent, for provider: ProviderType) throws {
        if provider != .gemini {
            throw ProviderCompatibilityError.notSupportedByProvider(
                feature: "Video input",
                provider: provider
            )
        }
    }

    /// ドキュメントコンテンツのプロバイダー互換性を検証
    ///
    /// - Throws: `ProviderCompatibilityError` 互換性がない場合
    public static func validate(_ document: DocumentContent, for provider: ProviderType) throws {
        try validateSupport(document.mediaType, for: provider)
    }
}
