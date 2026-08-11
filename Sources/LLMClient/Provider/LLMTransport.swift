import Foundation

// MARK: - LLMProvider Protocol

/// The seam where a concrete HTTP client is plugged in behind the provider-agnostic layers.
///
/// Implement it to add or replace a vendor backend — `AnthropicClient`, `OpenAIClient`,
/// `GeminiClient` and so on all sit here — and the layers above (`StructuredLLMClient`,
/// `ToolCallableClient`) work against it without knowing which vendor is underneath.
///
/// An implementation owns everything between the request value and the response value: building
/// the wire payload, the HTTP call, authentication, timeouts, retries, backoff on rate limits,
/// mapping vendor errors onto `LLMError`, and normalising `TokenUsage` to the contract that type
/// documents. None of that is provided here — this protocol is one method and no behaviour.
///
/// - Note: Library users call `StructuredLLMClient` or `ToolCallableClient`, not this. Tool
///   calling and streaming are layered on top by other protocols; a request here carries neither.
public protocol LLMProvider: Sendable {
    /// Sends one request and waits for the complete response.
    ///
    /// - Parameter request: The request to send.
    /// - Returns: The full response. There is no partial or streaming form.
    /// - Throws: `LLMError` for transport, authentication, and provider failures.
    func send(_ request: LLMRequest) async throws -> LLMResponse
}

// MARK: - LLMRequest

/// One request, in a shape every provider implementation can lower to its own wire format.
///
/// Covers plain generation and structured output. It deliberately has no `tools` field — tool
/// declarations join the request in the LLMTool layer, which is also why token counting for a
/// tool-enabled call cannot be derived from this value alone.
public struct LLMRequest: Sendable {
    /// The model to serve the request.
    public let model: LLMModel

    /// The conversation, oldest first. The whole array is re-sent on every call, so it is the
    /// dominant term in input token cost as a conversation grows.
    public let messages: [LLMMessage]

    /// Instructions applied ahead of the messages.
    ///
    /// Part of the stable prefix a provider can cache, so churn here — an interpolated timestamp,
    /// a per-request identifier — silently costs full price on every call. See `PromptCachePolicy`.
    public let systemPrompt: String?

    /// The schema constraining the reply. Plain text is generated when this is `nil`.
    public let responseSchema: JSONSchema?

    /// Sampling temperature.
    ///
    /// Passed through without validation or clamping; the accepted range is provider-specific, so
    /// an out-of-range value surfaces as a provider error rather than a local one.
    public let temperature: Double?

    /// Ceiling on output tokens.
    ///
    /// Hitting it truncates the reply mid-token and reports `.maxTokens` as the stop reason, which
    /// leaves structured output undecodable. `nil` uses the provider's own default.
    public let maxTokens: Int?

    /// How the stable prefix should be cached. See `PromptCachePolicy`.
    public let cachePolicy: PromptCachePolicy

    /// Creates a request.
    ///
    /// - Parameters:
    ///   - model: The model to serve the request.
    ///   - messages: The conversation, oldest first.
    ///   - systemPrompt: Instructions applied ahead of the messages.
    ///   - responseSchema: The schema constraining the reply, or `nil` for plain text.
    ///   - temperature: Sampling temperature, passed through unvalidated.
    ///   - maxTokens: Ceiling on output tokens, or `nil` for the provider default.
    ///   - cachePolicy: How to cache the stable prefix. Defaults to leaving it to the provider.
    public init(
        model: LLMModel,
        messages: [LLMMessage],
        systemPrompt: String? = nil,
        responseSchema: JSONSchema? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        cachePolicy: PromptCachePolicy = .implicit
    ) {
        self.model = model
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.responseSchema = responseSchema
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.cachePolicy = cachePolicy
    }
}

// MARK: - LLMModel

/// A model selection, spanning every supported vendor.
///
/// The typed cases exist so a wrong identifier fails to compile; `openRouter` and `custom` are the
/// escape hatches for identifiers this package does not know about, and are not validated.
public enum LLMModel: Sendable, Equatable {
    /// An Anthropic Claude model.
    case claude(ClaudeModel)

    /// An OpenAI GPT model.
    case gpt(GPTModel)

    /// A Google Gemini model.
    case gemini(GeminiModel)

    /// A DeepSeek model.
    case deepseek(DeepSeekModel)

    /// An xAI Grok model.
    case grok(GrokModel)

    /// A model hosted by Groq.
    case groq(GroqModel)

    /// A Mistral AI model.
    case mistral(MistralModel)

    /// An OpenRouter model, named by the identifier OpenRouter expects and passed through as-is.
    case openRouter(String)

    /// Any other identifier, passed through as-is. Nothing checks that it exists.
    case custom(String)

    /// The identifier sent on the wire.
    public var id: String {
        switch self {
        case .claude(let model):
            return model.id
        case .gpt(let model):
            return model.id
        case .gemini(let model):
            return model.id
        case .deepseek(let model):
            return model.id
        case .grok(let model):
            return model.id
        case .groq(let model):
            return model.id
        case .mistral(let model):
            return model.id
        case .openRouter(let id):
            return id
        case .custom(let id):
            return id
        }
    }
}
