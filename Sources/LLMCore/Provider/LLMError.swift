// LLMError.swift
// swift-llm-client

import Foundation

// MARK: - LLMError

/// LLM API エラー
public enum LLMError: Error, Sendable {
    /// 認証エラー（無効な API キー）
    case unauthorized

    /// レート制限超過
    case rateLimitExceeded

    /// 無効なリクエスト
    case invalidRequest(String)

    /// モデルが見つからない
    case modelNotFound(String)

    /// サーバーエラー
    case serverError(Int, String)

    /// ネットワークエラー
    case networkError(Error)

    /// 空のレスポンス
    case emptyResponse

    /// 無効なエンコーディング
    case invalidEncoding

    /// デコードエラー
    case decodingFailed(Error)

    /// モデルがプロバイダーに対応していない
    case modelNotSupported(model: String, provider: String)

    /// 構造化出力がサポートされていない
    case structuredOutputNotSupported(model: String)

    /// メディアタイプがプロバイダーでサポートされていない
    ///
    /// 音声や動画など、特定のプロバイダーでサポートされていないメディアが
    /// メッセージに含まれている場合に発生します。
    ///
    /// - Parameters:
    ///   - mediaType: サポートされていないメディアタイプ（例: "audio", "video"）
    ///   - provider: プロバイダー名（例: "Anthropic", "OpenAI"）
    case mediaNotSupported(mediaType: String, provider: String)

    /// コンテンツがブロックされた（安全性フィルター）
    case contentBlocked(reason: String?)

    /// 最大トークン数に達した
    case maxTokensReached

    /// タイムアウト
    case timeout

    /// 不明なエラー
    case unknown(Error)
}

extension LLMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid API key or unauthorized access"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .emptyResponse:
            return "Empty response from the API"
        case .invalidEncoding:
            return "Invalid text encoding in response"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .modelNotSupported(let model, let provider):
            return "Model \(model) is not supported by \(provider)"
        case .structuredOutputNotSupported(let model):
            return "Structured output is not supported by model: \(model)"
        case .mediaNotSupported(let mediaType, let provider):
            return "\(mediaType.capitalized) input is not supported by \(provider)"
        case .contentBlocked(let reason):
            return "Content blocked by safety filter\(reason.map { ": \($0)" } ?? "")"
        case .maxTokensReached:
            return "Maximum token limit reached"
        case .timeout:
            return "Request timed out"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
