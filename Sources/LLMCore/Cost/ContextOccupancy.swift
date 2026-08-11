import Foundation

// MARK: - ContextOccupancy

/// How much of a model's context window the conversation currently takes up.
///
/// Built from the token usage of the most recent request — the exact counts that came back with the
/// response — so a live occupancy meter costs no extra API call.
///
/// **Design**:
/// - `promptTokens` uses `TokenUsage.inputTokens` as it stands, i.e. the cache-inclusive total the
///   semantics contract guarantees. Cached tokens are not subtracted: they still fill the window,
///   they are only cheaper.
/// - When `windowSize` is `nil`, because the model profile does not state one, `free` and
///   `usedFraction` return `nil` instead of 0 or an invented figure. Callers then show absolute
///   counts only.
/// - The output reserve and the compaction buffer are the caller's policy; this value type only
///   holds what it is handed.
///
/// Maps straight onto the ACP `usage_update` of `session/update`: `used` to `used`, `windowSize` to
/// `size`.
public struct ContextOccupancy: Sendable, Hashable {

    /// Total size of the context window in tokens. Nil when the model profile does not state one.
    public let windowSize: Int?

    /// Tokens the prompt occupies, cache included.
    public let promptTokens: Int

    /// Part of the prompt that was served from the prompt cache.
    public let cacheReadTokens: Int

    /// Part of the prompt that was written into the prompt cache.
    public let cacheCreationTokens: Int

    /// Part of the prompt that did not go through the cache at all.
    public let freshInputTokens: Int

    /// Output tokens of the most recent response.
    public let outputTokens: Int

    /// Tokens held back for the next response. Caller policy; affects the free figure only.
    public let outputReserve: Int

    /// Tokens held back for compaction and safety margin. Caller policy; affects the free figure only.
    public let compactionBuffer: Int

    // MARK: - Designated init

    public init(
        windowSize: Int?,
        promptTokens: Int,
        cacheReadTokens: Int,
        cacheCreationTokens: Int,
        freshInputTokens: Int,
        outputTokens: Int,
        outputReserve: Int,
        compactionBuffer: Int
    ) {
        self.windowSize = windowSize
        self.promptTokens = promptTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.freshInputTokens = freshInputTokens
        self.outputTokens = outputTokens
        self.outputReserve = outputReserve
        self.compactionBuffer = compactionBuffer
    }

    // MARK: - Convenience init from usage

    /// Derives the occupancy from the token usage of a request.
    ///
    /// - Parameters:
    ///   - usage: Usage reported for the most recent request.
    ///   - windowSize: Total size of the context window, or nil when the model does not state one.
    ///   - outputReserve: Tokens to hold back for the response.
    ///   - compactionBuffer: Tokens to hold back for compaction and safety margin.
    public init(
        usage: TokenUsage,
        windowSize: Int?,
        outputReserve: Int = 0,
        compactionBuffer: Int = 0
    ) {
        self.init(
            windowSize: windowSize,
            promptTokens: usage.inputTokens,
            cacheReadTokens: usage.cacheReadTokens ?? 0,
            cacheCreationTokens: usage.cacheCreationTokens ?? 0,
            freshInputTokens: usage.freshInputTokens,
            outputTokens: usage.outputTokens,
            outputReserve: outputReserve,
            compactionBuffer: compactionBuffer
        )
    }

    /// Creates an occupancy from a total alone, with no cache breakdown.
    ///
    /// Use it when a total is all there is: an ACP `usage_update` carrying `used` and `size`, or a
    /// snapshot of the current context size. The whole amount is recorded as fresh input and the
    /// output count as 0, so the cache figures of the result are not evidence that nothing was cached.
    public init(
        used: Int,
        windowSize: Int?,
        outputReserve: Int = 0,
        compactionBuffer: Int = 0
    ) {
        self.init(
            windowSize: windowSize,
            promptTokens: used,
            cacheReadTokens: 0,
            cacheCreationTokens: 0,
            freshInputTokens: used,
            outputTokens: 0,
            outputReserve: outputReserve,
            compactionBuffer: compactionBuffer
        )
    }

    /// Derives the occupancy from a usage and a model profile, taking the window size from the profile.
    ///
    /// When `outputReserve` is not given, the model's `maxOutputTokens` is reserved. A provider
    /// rejects a request whose prompt plus requested output overflows the window, so the capacity an
    /// answer will claim is not really free, and reserving it keeps the free figure honest.
    public init(
        usage: TokenUsage,
        profile: ModelProfile,
        outputReserve: Int? = nil,
        compactionBuffer: Int = 0
    ) {
        self.init(
            usage: usage,
            windowSize: profile.contextWindow,
            outputReserve: outputReserve ?? (profile.maxOutputTokens ?? 0),
            compactionBuffer: compactionBuffer
        )
    }

    // MARK: - Derived

    /// Tokens currently filling the window, which is what ACP reports as used.
    @inlinable
    public var used: Int { promptTokens }

    /// Tokens a request may still add, or nil when the window size is unknown.
    ///
    /// The window size less the occupancy, the output reserve and the compaction buffer, clamped at
    /// zero. Zero means the reserves are already being eaten into, not that the window is full.
    @inlinable
    public var free: Int? {
        guard let windowSize else { return nil }
        return max(0, windowSize - promptTokens - outputReserve - compactionBuffer)
    }

    /// Share of the window the prompt fills, from 0.0 upward and able to pass 1.0.
    ///
    /// Nil when the window size is unknown or not positive. Reserves are ignored here, so this
    /// measures the raw window and not what a request may still add.
    @inlinable
    public var usedFraction: Double? {
        guard let windowSize, windowSize > 0 else { return nil }
        return Double(promptTokens) / Double(windowSize)
    }

    /// Whether the prompt has outgrown the window, which a provider answers with an error.
    ///
    /// False when the window size is unknown, so it never reports an overflow it cannot see.
    @inlinable
    public var isOverLimit: Bool {
        guard let windowSize else { return false }
        return promptTokens > windowSize
    }
}
