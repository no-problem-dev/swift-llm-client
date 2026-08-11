// LLMError.swift
// swift-llm-client

import Foundation

// MARK: - LLMError

/// Something that went wrong talking to a model provider.
public enum LLMError: Error, Sendable {
    /// The API key is missing, wrong, or not allowed to reach this model.
    case unauthorized

    /// The provider's rate limit was hit. Back off before retrying.
    case rateLimitExceeded

    /// The provider rejected the request as malformed, with its own explanation attached.
    case invalidRequest(String)

    /// The provider does not know the model identifier that was asked for.
    case modelNotFound(String)

    /// The provider failed on its own side, carrying the status code and the body it returned.
    case serverError(Int, String)

    /// The request never reached the provider.
    case networkError(Error)

    /// The provider answered with no content at all.
    case emptyResponse

    /// The response body was not decodable text.
    case invalidEncoding

    /// The response did not have the shape that was expected of it.
    case decodingFailed(Error)

    /// The model belongs to a different provider than the one it was requested from.
    case modelNotSupported(model: String, provider: String)

    /// The model cannot be made to answer in a fixed schema.
    case structuredOutputNotSupported(model: String)

    /// The message carries media this provider cannot take.
    ///
    /// Raised before the request goes out, when a message holds audio, video or another kind the
    /// chosen provider does not accept.
    ///
    /// - Parameters:
    ///   - mediaType: The kind that is not accepted, such as "audio" or "video".
    ///   - provider: Provider name, such as "Anthropic" or "OpenAI".
    case mediaNotSupported(mediaType: String, provider: String)

    /// A safety filter blocked the content.
    case contentBlocked(reason: String?)

    /// Generation ran into the output cap.
    case maxTokensReached

    /// The request did not finish within the time allowed.
    case timeout

    /// An error that fits none of the other cases.
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
