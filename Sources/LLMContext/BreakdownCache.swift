import Foundation
import CryptoKit
import LLMClient
import LLMTool

// MARK: - BreakdownCache

/// Reuses the parts of a breakdown that cannot have changed, so a growing conversation costs one
/// measurement instead of many.
///
/// What invalidates what: changing the system prompt or the tool groups invalidates every cached
/// segment and forces a full re-measurement; appending messages invalidates only the conversation
/// segment. That asymmetry holds because the marginal cost of the system prompt and of each tool
/// group is a difference between two counts taken over the same messages, so the messages cancel
/// out of it.
///
/// The saving is the whole point of the type: an update after a new turn drops from one counting
/// request per rung — two plus the number of tool groups — to a single one.
///
/// - Note: The reuse is an approximation. It ignores the boundary tokens that shift when messages
///   grow, and the total it reports on the cheap path is arithmetic rather than measured. A
///   breakdown is for showing where the window went; the occupancy figure beside it is the exact
///   one, and it comes from reported usage rather than from here.
public actor BreakdownCache {

    private let counter: any TokenCounting
    private let engine: SegmentBreakdownEngine

    /// Signature of the system prompt and tool groups the cached figures were measured against.
    private var signature: String?

    /// Marginal cost of each system and tool segment, with the conversation segment left out
    /// because it is the one that has to be re-measured.
    private var cachedMarginals: [ContextSegment: Int] = [:]

    public init(counter: any TokenCounting) {
        self.counter = counter
        self.engine = SegmentBreakdownEngine(counter: counter)
    }

    /// Returns the breakdown, re-measuring only what the change could have affected.
    ///
    /// One counting request when just the messages moved; the full ladder when the system prompt
    /// or the tool groups differ from what was cached. On the cheap path the total is derived by
    /// adding the cached marginals to the freshly measured baseline rather than measured outright.
    ///
    /// - Parameters:
    ///   - modelID: The model whose tokenizer applies. Not part of the cache signature, so
    ///     switching models between calls reuses figures measured under the previous tokenizer;
    ///     invalidate first when the model changes.
    ///   - systemPrompt: The system prompt. A change invalidates every cached segment.
    ///   - messages: The conversation, always re-measured.
    ///   - toolGroups: Tool sets paired with the segment each is charged to. A change to any
    ///     tool's name or description invalidates every cached segment.
    public func breakdown(
        modelID: String,
        systemPrompt: String?,
        messages: [LLMMessage],
        toolGroups: [ToolGroup] = []
    ) async throws -> SegmentBreakdown {
        let sig = Self.signature(systemPrompt: systemPrompt, toolGroups: toolGroups)

        if signature == sig {
            // Only the messages moved: re-measure the baseline and reuse the marginals.
            let bare = try await counter.countInputTokens(
                modelID: modelID, systemPrompt: nil, messages: messages, tools: nil
            )
            var per = cachedMarginals
            per[.conversationHistory, default: 0] += bare
            let total = bare + cachedMarginals.values.reduce(0, +)
            return SegmentBreakdown(perSegment: per, totalMeasured: total)
        }

        // The system prompt or the tools changed: run the full ladder and cache the marginals.
        let full = try await engine.breakdown(
            modelID: modelID, systemPrompt: systemPrompt, messages: messages, toolGroups: toolGroups
        )
        var marginals = full.perSegment
        marginals[.conversationHistory] = nil
        signature = sig
        cachedMarginals = marginals
        return full
    }

    /// Drops the cached figures so the next breakdown runs the full ladder.
    ///
    /// Needed where a change escapes the signature: switching models, or editing a tool's argument
    /// schema without touching its name or description.
    public func invalidate() {
        signature = nil
        cachedMarginals = [:]
    }

    // MARK: - Signature

    /// Builds a stable signature of the system prompt and the tool groups.
    ///
    /// A tool is identified by its name and description only. Its argument schema is not hashed,
    /// so editing a schema alone leaves the signature unchanged and the stale marginals in place.
    static func signature(systemPrompt: String?, toolGroups: [ToolGroup]) -> String {
        var hasher = SHA256()
        hasher.update(data: Data((systemPrompt ?? "").utf8))
        hasher.update(data: Data([0xff]))
        for group in toolGroups {
            hasher.update(data: Data(group.segment.rawValue.utf8))
            hasher.update(data: Data([0xfe]))
            for tool in group.tools.tools {
                hasher.update(data: Data(tool.toolName.utf8))
                hasher.update(data: Data([0x1f]))
                hasher.update(data: Data(tool.toolDescription.utf8))
                hasher.update(data: Data([0x1e]))
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
