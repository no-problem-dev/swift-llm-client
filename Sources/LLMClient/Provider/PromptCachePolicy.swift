import Foundation

// MARK: - PromptCachePolicy

/// What a caller wants done about caching the stable head of a request.
///
/// The stable prefix means the system prompt, the tool declarations, and the tool configuration —
/// the part of a request that is meant to be identical call after call. This type expresses the
/// intent in provider-neutral terms; lowering it to a mechanism is each provider implementation's
/// job:
///
/// - Gemini: creates a `cachedContents` resource and references it.
/// - Anthropic: places a `cache_control` breakpoint at the end of the stable prefix.
/// - Providers with automatic caching only, such as OpenAI: treated the same as `.implicit`
///   (graceful degradation).
///
/// **Caching is a prefix match, and the match is over bytes.** Providers render a request as
/// tools, then system prompt, then messages; a single changed byte anywhere in that head
/// invalidates everything after it. Interpolating a timestamp, a UUID, or a per-user identifier
/// into the system prompt, or serialising tool declarations in a non-deterministic order, means
/// nothing is ever reused — with no error to say so. Changing the model or the tool set has the
/// same effect, since caches are scoped to both.
///
/// TTL follows each provider's own lifecycle: Gemini expires at a fixed time (reading does not
/// extend it; the update API does), while Anthropic slides the expiry forward on each read.
///
/// Whether any of it actually worked is visible in `TokenUsage.cacheReadTokens` and
/// `cacheCreationTokens`. Repeated calls that leave `cacheReadTokens` at zero mean the prefix is
/// not stable, or is shorter than the provider's minimum cacheable length — providers cache
/// nothing below that threshold and report no error.
public enum PromptCachePolicy: Sendable, Hashable, Codable {
    /// Leaves caching entirely to the provider.
    ///
    /// No cache instruction is sent. A stable prefix may still be cached automatically by the
    /// provider, but nothing guarantees it, and there is no way to ask for a particular lifetime.
    case implicit

    /// Asks the provider to cache the stable prefix explicitly.
    ///
    /// Worth it when the prefix will be reused several times within the lifetime: writing a cache
    /// entry costs more than an ordinary uncached read, so a prefix sent once ends up more
    /// expensive than it would have been under `.implicit`.
    ///
    /// - Parameter ttl: How long the entry should live. Providers may round it to their own
    ///   granularity.
    case explicitPrefix(ttl: Duration)
}

// MARK: - PromptCacheReleasing

/// Adopted by clients whose explicit caches are server-side resources they own.
///
/// Where a provider bills cached content as storage — Gemini does — releasing at the end of a
/// session stops the charge for the remaining TTL. Providers with no such resource (Anthropic,
/// OpenAI) need not adopt it; callers branch on `as? PromptCacheReleasing` and simply skip the
/// call when it is absent.
public protocol PromptCacheReleasing {
    /// Releases every cache resource this client created.
    ///
    /// Call it when a session ends. Any subsequent request pays full price for the prefix again.
    func releasePromptCaches() async
}
