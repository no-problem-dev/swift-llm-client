import Foundation
import LLMClient
import LLMTool

// MARK: - AgentContextTracker

/// host / 各サブエージェント (A2) ごとのコンテキストウィンドウ状況を集約する。
///
/// - キーは不透明な `agentID: String`（host・各 delegation を識別）。
///   `swift-llm-agent` の具体型に依存しないため、純粋ドメイン層（LLMContext）に置ける。
/// - `record(...)`: `usage` から **正確・即時** に `ContextOccupancy`（ライブメーター）を更新。
/// - `refreshBreakdown(...)`: `count_tokens` 差分でカテゴリ別内訳を **オンデマンド** 取得。
///   per-agent の `BreakdownCache` を保持し、メッセージのみ変化時は 1 回計測に抑える。
///
/// `@MainActor` は SwiftUI からの参照を容易にするため（UsageLedger と同方針）。
/// `@Observable` 等の UI 関心は app 層の ViewModel が担い、本型は Observation 非依存に保つ。
@MainActor
public final class AgentContextTracker {

    /// agentID → 最新レポート。
    public private(set) var reports: [String: ContextReport] = [:]

    private let counter: any TokenCounting
    private var caches: [String: BreakdownCache] = [:]

    public init(counter: any TokenCounting) {
        self.counter = counter
    }

    // MARK: - Live occupancy（usage 由来・正確）

    /// `ModelProfile` からウィンドウ/出力予約を解決して占有を更新する。
    public func record(
        agentID: String,
        usage: TokenUsage,
        profile: ModelProfile,
        compactionBuffer: Int = 0
    ) {
        let occ = ContextOccupancy(usage: usage, profile: profile, compactionBuffer: compactionBuffer)
        setOccupancy(occ, for: agentID)
    }

    /// ウィンドウサイズ等を明示して占有を更新する。
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

    // MARK: - On-demand breakdown（count_tokens 差分・per-agent キャッシュ）

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

    public func reset(agentID: String) {
        reports[agentID] = nil
        caches[agentID] = nil
    }

    public func resetAll() {
        reports = [:]
        caches = [:]
    }

    // MARK: - Private

    private func setOccupancy(_ occupancy: ContextOccupancy, for agentID: String) {
        // 既存の内訳は保持し、占有のみ差し替える。
        reports[agentID] = ContextReport(occupancy: occupancy, breakdown: reports[agentID]?.breakdown)
    }

    private func setBreakdown(_ breakdown: SegmentBreakdown, for agentID: String) {
        if let existing = reports[agentID] {
            reports[agentID] = ContextReport(occupancy: existing.occupancy, breakdown: breakdown)
        } else {
            // 占有未記録時は内訳総量から最小占有を導出（ウィンドウ不明）。
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
