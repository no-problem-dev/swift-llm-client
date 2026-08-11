import Foundation

// MARK: - Pricing

/// What a model charges, in US dollars per million tokens.
///
/// The rates themselves are plain doubles; only a computed amount is wrapped in a currency type
/// before it goes up to the layers above.
public struct Pricing: Sendable, Hashable, Codable {
    /// Price tiers ordered from the smallest input size upward.
    ///
    /// Usually a single entry. Context-tiered models such as Gemini 2.5 and 3.1 Pro have several,
    /// and get more expensive once the prompt passes a threshold.
    public let tiers: [PricingTier]

    /// Rate for input tokens served from the prompt cache. Nil when the model has no prompt caching.
    public let cacheReadPerMTok: Double?

    /// Rate for writing into the short-lifetime cache.
    ///
    /// Anthropic charges this for a 5-minute write. OpenAI and Gemini bill no separate write, so it
    /// is usually nil for them.
    public let cacheWriteShortPerMTok: Double?

    /// Rate for writing into the long-lifetime cache, which only Anthropic's 1-hour cache uses.
    public let cacheWriteLongPerMTok: Double?

    /// Rate for reasoning tokens.
    ///
    /// Nil where reasoning is billed at the plain output rate, as with OpenAI's o-series and Gemini
    /// Flash thinking.
    public let reasoningPerMTok: Double?

    public init(
        tiers: [PricingTier],
        cacheReadPerMTok: Double? = nil,
        cacheWriteShortPerMTok: Double? = nil,
        cacheWriteLongPerMTok: Double? = nil,
        reasoningPerMTok: Double? = nil
    ) {
        precondition(!tiers.isEmpty, "Pricing must have at least one tier")
        precondition(
            tiers.dropLast().allSatisfy { $0.upToInputTokens != nil },
            "Only the last tier may have an unbounded upToInputTokens"
        )
        self.tiers = tiers
        self.cacheReadPerMTok = cacheReadPerMTok
        self.cacheWriteShortPerMTok = cacheWriteShortPerMTok
        self.cacheWriteLongPerMTok = cacheWriteLongPerMTok
        self.reasoningPerMTok = reasoningPerMTok
    }

    /// Creates a price sheet for a model that charges one rate whatever the prompt size.
    public static func flat(
        inputPerMTok: Double,
        outputPerMTok: Double,
        cacheReadPerMTok: Double? = nil,
        cacheWriteShortPerMTok: Double? = nil,
        cacheWriteLongPerMTok: Double? = nil,
        reasoningPerMTok: Double? = nil
    ) -> Pricing {
        Pricing(
            tiers: [PricingTier(upToInputTokens: nil,
                                inputPerMTok: inputPerMTok,
                                outputPerMTok: outputPerMTok)],
            cacheReadPerMTok: cacheReadPerMTok,
            cacheWriteShortPerMTok: cacheWriteShortPerMTok,
            cacheWriteLongPerMTok: cacheWriteLongPerMTok,
            reasoningPerMTok: reasoningPerMTok
        )
    }

    /// Returns the tier that applies to a prompt of the given size.
    ///
    /// The first tier whose cap covers the count wins; the last tier answers everything above them.
    ///
    /// - Parameter tokens: Total input tokens of the request, cached tokens included.
    @inlinable
    public func tier(forInputTokens tokens: Int) -> PricingTier {
        for tier in tiers {
            if let cap = tier.upToInputTokens {
                if tokens <= cap { return tier }
            } else {
                return tier
            }
        }
        return tiers.last!
    }
}

// MARK: - PricingTier

public struct PricingTier: Sendable, Hashable, Codable {
    /// Largest input size this tier covers, inclusive.
    ///
    /// Nil makes the tier unbounded, which only the last tier of a price sheet is allowed to be.
    public let upToInputTokens: Int?
    public let inputPerMTok: Double
    public let outputPerMTok: Double

    public init(upToInputTokens: Int?, inputPerMTok: Double, outputPerMTok: Double) {
        self.upToInputTokens = upToInputTokens
        self.inputPerMTok = inputPerMTok
        self.outputPerMTok = outputPerMTok
    }
}
