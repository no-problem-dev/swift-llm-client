import Foundation

// MARK: - GenerationResult

/// A decoded structured result together with what the call cost and how it ended.
///
/// Returned by `generateWithUsage`. The plain `generate` methods return only the decoded value,
/// so this is the only form that lets a caller attribute cost, detect a truncated response, or
/// inspect the JSON the model actually produced.
///
/// ## Example
///
/// ```swift
/// let client = GeminiClient(apiKey: "...")
///
/// @Structured("User information")
/// struct UserInfo {
///     @StructuredField("User name") var name: String
///     @StructuredField("Age") var age: Int
/// }
///
/// let result: GenerationResult<UserInfo> = try await client.generateWithUsage(
///     input: "Taro Yamada is 35 years old.",
///     model: .flash3
/// )
///
/// print(result.result.name)           // "Taro Yamada"
/// print(result.usage.inputTokens)     // input tokens, cache included
/// print(result.usage.outputTokens)    // output tokens, reasoning included
/// print(result.usage.totalTokens)     // input + output
/// ```
public struct GenerationResult<T: StructuredProtocol>: Sendable {
    /// The decoded value.
    public let result: T

    /// What the call consumed, for cost attribution.
    ///
    /// Cached and reasoning tokens are folded into `inputTokens` and `outputTokens` rather than
    /// reported alongside them; see `TokenUsage` for the exact subset relationships before
    /// multiplying anything by a price.
    public let usage: TokenUsage

    /// The model identifier the provider reports having served.
    ///
    /// Worth reading rather than assuming: providers commonly resolve an alias to a dated
    /// snapshot, so this can differ from the model that was requested — which matters when
    /// per-model pricing is applied to `usage`.
    public let model: String

    /// The raw JSON the model returned, before decoding.
    ///
    /// The only way to see what the model actually produced once decoding has succeeded. Useful
    /// when the decoded values are wrong rather than absent, and when logging a call for replay.
    public let rawText: String

    /// Why the model stopped generating.
    ///
    /// `.endTurn` is a normal finish. `.maxTokens` means the output ceiling was reached, which for
    /// structured output usually means the JSON was cut off — treat a decoded value that arrives
    /// alongside it as suspect, and raise `maxTokens`.
    public let stopReason: LLMResponse.StopReason?

    // MARK: - Initializer

    /// Creates a result. Called by provider clients after decoding; callers receive these rather
    /// than build them.
    ///
    /// - Parameters:
    ///   - result: The decoded value.
    ///   - usage: Tokens consumed by the call.
    ///   - model: The model identifier the provider served.
    ///   - rawText: The raw JSON returned by the model.
    ///   - stopReason: Why generation stopped.
    public init(
        result: T,
        usage: TokenUsage,
        model: String,
        rawText: String,
        stopReason: LLMResponse.StopReason?
    ) {
        self.result = result
        self.usage = usage
        self.model = model
        self.rawText = rawText
        self.stopReason = stopReason
    }
}

// MARK: - Convenience Extensions

extension GenerationResult {
    /// Returns a result carrying a transformed value and the original call metadata.
    ///
    /// Usage, model, raw JSON, and stop reason are copied across untouched, so mapping never
    /// invents a second call and the same tokens are never counted twice.
    ///
    /// - Parameter transform: Converts the decoded value; its failures propagate to the caller.
    /// - Returns: A result of the new type carrying the same call metadata.
    public func map<U: StructuredProtocol>(_ transform: (T) throws -> U) rethrows -> GenerationResult<U> {
        GenerationResult<U>(
            result: try transform(result),
            usage: usage,
            model: model,
            rawText: rawText,
            stopReason: stopReason
        )
    }
}

// MARK: - CustomDebugStringConvertible

extension GenerationResult: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        GenerationResult(
            model: \(model),
            usage: TokenUsage(input: \(usage.inputTokens), output: \(usage.outputTokens), total: \(usage.totalTokens)),
            stopReason: \(stopReason.map { String(describing: $0) } ?? "nil"),
            rawText: \(rawText.prefix(100))\(rawText.count > 100 ? "..." : "")
        )
        """
    }
}
