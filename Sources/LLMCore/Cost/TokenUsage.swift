import Foundation

// MARK: - TokenUsage

/// Token counts an LLM API reported for one request.
///
/// **Semantics contract** — provider converters are responsible for normalizing raw responses to it:
/// - `inputTokens` is the **total input token count, cache included**.
///   - Anthropic reports fresh input only, so its converter adds the cache read and cache creation
///     counts back in.
///   - OpenAI and Gemini already report a cache-inclusive total, so their raw value is used as is.
/// - `outputTokens` is the **total output token count: visible output plus reasoning**.
///   - `reasoningTokens` is a subset of `outputTokens`.
/// - `cacheReadTokens` and `cacheCreationTokens` are subsets of `inputTokens`.
///   - `freshInputTokens = inputTokens - cacheRead - cacheCreation`
public struct TokenUsage: Sendable, Hashable, Codable {
    /// Total input tokens, including everything served from or written to the prompt cache.
    public let inputTokens: Int

    /// Total output tokens, including reasoning tokens the model did not show.
    public let outputTokens: Int

    /// Reasoning tokens, a subset of the output count. Nil when the provider does not report them.
    public let reasoningTokens: Int?

    /// Input tokens served from the prompt cache, a subset of the input count.
    public let cacheReadTokens: Int?

    /// Input tokens written into the prompt cache, a subset of the input count.
    public let cacheCreationTokens: Int?

    /// Which cache lifetime the write was billed at. Nil when nothing was written or the provider
    /// offers a single lifetime.
    public let cacheTier: CacheTier?

    /// Input tokens that neither came from the cache nor were written to it.
    ///
    /// Clamped at zero, so a provider reporting subsets larger than the total cannot make it negative.
    @inlinable
    public var freshInputTokens: Int {
        max(0, inputTokens - (cacheReadTokens ?? 0) - (cacheCreationTokens ?? 0))
    }

    /// Output tokens the model actually showed, with reasoning tokens taken out.
    @inlinable
    public var visibleOutputTokens: Int {
        max(0, outputTokens - (reasoningTokens ?? 0))
    }

    /// Input plus output. Reasoning is not added again, since it is already inside the output count.
    @inlinable
    public var totalTokens: Int { inputTokens + outputTokens }

    public init(
        inputTokens: Int,
        outputTokens: Int,
        reasoningTokens: Int? = nil,
        cacheReadTokens: Int? = nil,
        cacheCreationTokens: Int? = nil,
        cacheTier: CacheTier? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheTier = cacheTier
    }
}

// MARK: - CacheTier

/// How long a prompt cache entry stays alive, which decides the rate its creation is billed at.
public enum CacheTier: String, Sendable, Hashable, Codable {
    /// Short lifetime: Anthropic's 5-minute cache. The ordinary caches of OpenAI and Gemini are
    /// reported as this too.
    case short
    /// Long lifetime: Anthropic's 1-hour cache.
    case long
}

// MARK: - Aggregation

extension TokenUsage {
    public static var zero: TokenUsage {
        TokenUsage(inputTokens: 0, outputTokens: 0)
    }

    /// Returns the two usages added together, for totalling the steps of a run.
    ///
    /// The sum carries no cache tier: every step can be billed at a different lifetime, so a single
    /// tier cannot describe the total. An optional component stays nil only when it is nil on both
    /// sides.
    ///
    /// - Parameter other: The usage to add to this one.
    public func adding(_ other: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens,
            reasoningTokens: Self.optionalSum(reasoningTokens, other.reasoningTokens),
            cacheReadTokens: Self.optionalSum(cacheReadTokens, other.cacheReadTokens),
            cacheCreationTokens: Self.optionalSum(cacheCreationTokens, other.cacheCreationTokens),
            cacheTier: nil
        )
    }

    private static func optionalSum(_ a: Int?, _ b: Int?) -> Int? {
        switch (a, b) {
        case (nil, nil): return nil
        case (let x?, nil): return x
        case (nil, let y?): return y
        case (let x?, let y?): return x + y
        }
    }
}
