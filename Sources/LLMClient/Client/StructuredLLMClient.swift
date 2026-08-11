import Foundation

// MARK: - StructuredLLMClient

/// The entry point for getting model output back as a decoded Swift value instead of text.
///
/// Any type conforming to `StructuredProtocol` can be named as the result type. Naming it is the
/// whole request: schema derivation, injecting the schema into the call, and parsing the JSON the
/// model returns all happen inside the client.
///
/// Two families of methods exist and they differ in what they throw away.
/// `generateWithUsage` returns the decoded value together with the token usage, the model
/// identifier the provider actually served, and the raw JSON. `generate` returns only the decoded
/// value and drops everything else — including `TokenUsage`, which is the only record of what the
/// call cost. There is no way to recover it afterwards, so use `generate` only where cost tracking
/// is genuinely not wanted.
///
/// ## Example
///
/// ```swift
/// @Structured("Extracted city information")
/// struct CityInfo {
///     @StructuredField("City name")
///     var name: String
///     @StructuredField("Population")
///     var population: Int
/// }
///
/// let result: CityInfo = try await client.generate(
///     input: "Tokyo has a population of about 14 million.",
///     model: .sonnet
/// )
/// ```
public protocol StructuredLLMClient<Model>: Sendable {
    /// The provider-specific model selector this client accepts, usually an enumeration of one
    /// vendor's model identifiers.
    associatedtype Model: Sendable

    /// Generates a structured value from a single prompt and reports what the call consumed.
    ///
    /// This is one of the two members a conforming client must implement; everything else on this
    /// protocol is derived from it.
    ///
    /// - Parameters:
    ///   - input: The prompt, optionally carrying images, audio, or video.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the input. Providers generally treat this
    ///     as a stable prefix, so keeping it byte-identical across calls is what makes prompt
    ///     caching possible.
    ///   - temperature: Sampling temperature. Passed through unvalidated; the accepted range
    ///     differs by provider.
    ///   - maxTokens: Ceiling on output tokens. A ceiling low enough to cut off the JSON leaves
    ///     the response undecodable, so leave headroom above the expected result size.
    /// - Throws: `LLMError` for transport and provider failures, or a decoding error when the
    ///   returned JSON does not match the schema.
    func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: SystemPrompt?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T>

    /// Generates a structured value from a conversation history and reports what the call consumed.
    ///
    /// Use this rather than the single-prompt form whenever earlier turns must stay in context.
    /// The whole history is re-sent on every call, so token usage grows with the conversation.
    ///
    /// - Parameters:
    ///   - messages: The conversation so far, oldest first. Tool calls left without a matching
    ///     result are rejected by some providers; see `sanitizeOrphanedToolUses()`.
    ///   - model: The model to serve the request.
    ///   - systemPrompt: Instructions applied ahead of the history.
    ///   - temperature: Sampling temperature. Passed through unvalidated; the accepted range
    ///     differs by provider.
    ///   - maxTokens: Ceiling on output tokens.
    /// - Throws: `LLMError` for transport and provider failures, or a decoding error when the
    ///   returned JSON does not match the schema.
    func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T>
}

// MARK: - Default Implementations

extension StructuredLLMClient {

    // MARK: - generateWithUsage (default arguments)

    /// Generates a structured value from a prompt, letting the optional arguments default.
    ///
    /// This exists only to supply default values, which a protocol requirement cannot declare. It
    /// forwards straight back through the protocol.
    ///
    /// - Warning: Because it forwards through the protocol, a conforming type that does not
    ///   implement the corresponding requirement recurses here forever instead of failing to
    ///   compile. Every conformance must implement both `generateWithUsage` requirements.
    public func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> GenerationResult<T> {
        try await generateWithUsage(
            input: input,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// Generates a structured value from a conversation history, letting the optional arguments
    /// default.
    ///
    /// - Warning: Like its single-prompt counterpart, this forwards through the protocol, so a
    ///   conformance that omits the requirement recurses here forever.
    public func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> GenerationResult<T> {
        try await generateWithUsage(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    // MARK: - generate (result only, delegates to generateWithUsage)

    /// Generates a structured value from a prompt and discards everything except the value.
    ///
    /// The call still costs the same tokens, but the `TokenUsage`, the served model identifier,
    /// the raw JSON, and the stop reason are dropped and cannot be recovered. Reach for
    /// `generateWithUsage` wherever cost has to be attributed or a truncated response has to be
    /// detected.
    public func generate<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        let result: GenerationResult<T> = try await generateWithUsage(
            input: input,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return result.result
    }

    /// Generates a structured value from a conversation history and discards everything except the
    /// value.
    ///
    /// Token usage grows with every turn resent, and this overload throws that accounting away, so
    /// it is the worst place to lose it. Prefer `generateWithUsage` for multi-turn work.
    public func generate<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        let result: GenerationResult<T> = try await generateWithUsage(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return result.result
    }
}
