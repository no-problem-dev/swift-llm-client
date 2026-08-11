import Foundation
import LLMClient
import LLMTool

// MARK: - AgentContextTracker

/// Keeps one context-window report per agent, for the host and every subagent it delegates to.
///
/// Agents are identified by an opaque string the caller chooses, so this type needs no dependency
/// on any agent implementation and can stay in the domain layer.
///
/// The two halves of a report are gathered very differently, and the split is the point of this
/// type. Recording usage updates the live occupancy from figures the response already carried, so
/// it is exact and costs nothing. Refreshing the breakdown spends token-counting requests to
/// attribute the window to categories, so it is on demand and cached per agent.
///
/// Runs on the main actor purely to be easy to read from SwiftUI. It stays free of Observation
/// itself; making the reports observable is the app layer's business.
@MainActor
public final class AgentContextTracker {

    /// The latest report for each agent, keyed by agent identifier.
    public private(set) var reports: [String: ContextReport] = [:]

    private let counter: any TokenCounting
    private var caches: [String: BreakdownCache] = [:]

    public init(counter: any TokenCounting) {
        self.counter = counter
    }

    // MARK: - Live occupancy (exact, from usage)

    /// Updates an agent's live occupancy, taking the window size and output reserve from the model.
    ///
    /// Costs no request: the figures come from the usage the last response already carried. Call it
    /// after every turn. Any breakdown already held for the agent is kept as it was, so the report
    /// mixes a current occupancy with a breakdown that may be several turns old.
    public func record(
        agentID: String,
        usage: TokenUsage,
        profile: ModelProfile,
        compactionBuffer: Int = 0
    ) {
        let occ = ContextOccupancy(usage: usage, profile: profile, compactionBuffer: compactionBuffer)
        setOccupancy(occ, for: agentID)
    }

    /// Updates an agent's live occupancy with an explicitly stated window size.
    ///
    /// For a model with no profile to consult. Passing nil for the window size leaves the report
    /// showing absolute counts with no free figure and no percentage, rather than inventing one.
    public func record(
        agentID: String,
        usage: TokenUsage,
        windowSize: Int?,
        outputReserve: Int = 0,
        compactionBuffer: Int = 0
    ) {
        let occ = ContextOccupancy(
            usage: usage, windowSize: windowSize,
            outputReserve: outputReserve, compactionBuffer: compactionBuffer
        )
        setOccupancy(occ, for: agentID)
    }

    // MARK: - On-demand breakdown (differenced token counts, cached per agent)

    /// Measures how an agent's context window is divided between categories.
    ///
    /// Unlike recording occupancy, this spends token-counting requests: one per measurement rung,
    /// so roughly two plus the number of tool groups on a cold cache, and one when only the
    /// messages have changed since the last refresh. Call it when a user opens a breakdown view or
    /// before deciding what to compact — not on every turn.
    ///
    /// The result replaces the agent's breakdown and leaves its occupancy alone. Where no
    /// occupancy has been recorded yet, one is derived from the measured total with the window
    /// size left unknown.
    ///
    /// - Parameters:
    ///   - agentID: The agent whose report to update.
    ///   - modelID: The model whose tokenizer applies. Counts from different models are not
    ///     comparable.
    ///   - systemPrompt: The system prompt, or nil to leave that rung out.
    ///   - messages: The conversation, used unchanged at every rung so that differences isolate
    ///     the segment being measured.
    ///   - toolGroups: Tool sets paired with the segment each is charged to, measured cumulatively
    ///     in the order given.
    @discardableResult
    public func refreshBreakdown(
        agentID: String,
        modelID: String,
        systemPrompt: String?,
        messages: [LLMMessage],
        toolGroups: [ToolGroup] = []
    ) async throws -> SegmentBreakdown {
        let cache = caches[agentID] ?? BreakdownCache(counter: counter)
        caches[agentID] = cache
        let breakdown = try await cache.breakdown(
            modelID: modelID, systemPrompt: systemPrompt, messages: messages, toolGroups: toolGroups
        )
        setBreakdown(breakdown, for: agentID)
        return breakdown
    }

    // MARK: - Access

    public func report(for agentID: String) -> ContextReport? { reports[agentID] }

    /// Forgets an agent's report and its cached measurements.
    ///
    /// Call it when a conversation is cleared or a subagent finishes; leaving the entry behind
    /// shows an occupancy for a context that no longer exists.
    public func reset(agentID: String) {
        reports[agentID] = nil
        caches[agentID] = nil
    }

    /// Forgets every report and cache, for the host and all subagents alike.
    public func resetAll() {
        reports = [:]
        caches = [:]
    }

    // MARK: - Private

    private func setOccupancy(_ occupancy: ContextOccupancy, for agentID: String) {
        // Keep whatever breakdown is already there; only the occupancy is replaced.
        reports[agentID] = ContextReport(occupancy: occupancy, breakdown: reports[agentID]?.breakdown)
    }

    private func setBreakdown(_ breakdown: SegmentBreakdown, for agentID: String) {
        if let existing = reports[agentID] {
            reports[agentID] = ContextReport(occupancy: existing.occupancy, breakdown: breakdown)
        } else {
            // With no occupancy recorded, derive a minimal one from the measured total, window unknown.
            let occupancy = ContextOccupancy(
                windowSize: nil,
                promptTokens: breakdown.totalMeasured,
                cacheReadTokens: 0, cacheCreationTokens: 0,
                freshInputTokens: breakdown.totalMeasured,
                outputTokens: 0, outputReserve: 0, compactionBuffer: 0
            )
            reports[agentID] = ContextReport(occupancy: occupancy, breakdown: breakdown)
        }
    }
}
