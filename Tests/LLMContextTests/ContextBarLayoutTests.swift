import Testing
import Foundation
@testable import LLMContext
@testable import LLMClient

@Suite("ContextBarLayout 表示変換")
struct ContextBarLayoutTests {

    // MARK: - 占有モード（内訳なし）

    @Test("内訳なし: fresh / cached / free 区画と比率")
    func occupancyModeSegments() {
        let usage = TokenUsage(
            inputTokens: 120_000, outputTokens: 0,
            cacheReadTokens: 90_000, cacheCreationTokens: 10_000
        )
        let occ = ContextOccupancy(usage: usage, windowSize: 1_000_000) // reserve 0
        let layout = ContextBarLayout(report: ContextReport(occupancy: occ))

        let kinds = layout.segments.map(\.kind)
        #expect(kinds == [.fresh, .cached, .free])

        let fresh = layout.segments.first { $0.kind == .fresh }!
        let cached = layout.segments.first { $0.kind == .cached }!
        let free = layout.segments.first { $0.kind == .free }!
        #expect(fresh.tokens == 20_000)             // 120k - (90k+10k)
        #expect(cached.tokens == 100_000)
        #expect(free.tokens == 1_000_000 - 120_000) // reserve 0
        #expect(abs(fresh.fraction - 0.02) < 1e-9)
        #expect(abs(cached.fraction - 0.10) < 1e-9)
    }

    // MARK: - 内訳モード

    @Test("内訳あり: カテゴリ別区画 + 空き、順序が安定")
    func breakdownModeSegments() {
        let usage = TokenUsage(inputTokens: 130_000, outputTokens: 0)
        let occ = ContextOccupancy(usage: usage, windowSize: 1_000_000)
        let breakdown = SegmentBreakdown(
            perSegment: [
                .systemPrompt: 8_000,
                .toolDefinitions: 12_000,
                .mcpToolDefinitions: 31_000,
                .conversationHistory: 79_000,
            ],
            totalMeasured: 130_000
        )
        let layout = ContextBarLayout(report: ContextReport(occupancy: occ, breakdown: breakdown))

        let kinds = layout.segments.map(\.kind)
        // memoryFiles / latestToolResults は 0 なので出ない。順序は安定。
        #expect(kinds == [.systemPrompt, .toolDefinitions, .mcpToolDefinitions, .conversationHistory, .free])
        #expect(layout.segments.first { $0.kind == .mcpToolDefinitions }?.tokens == 31_000)
        #expect(abs((layout.segments.first { $0.kind == .mcpToolDefinitions }?.fraction ?? 0) - 0.031) < 1e-9)
    }

    // MARK: - ウィンドウ不明（silent fallback 排除）

    @Test("windowSize 不明: 空き区画を出さず used で正規化")
    func unknownWindowNoFreeSegment() {
        let usage = TokenUsage(inputTokens: 50_000, outputTokens: 0)
        let occ = ContextOccupancy(usage: usage, windowSize: nil)
        let layout = ContextBarLayout(report: ContextReport(occupancy: occ))

        #expect(layout.windowSize == nil)
        #expect(!layout.segments.contains { $0.kind == .free }) // 空きを捏造しない
        // used で正規化 → fresh が全体を占める
        #expect(layout.segments.first { $0.kind == .fresh }?.tokens == 50_000)
        #expect(abs((layout.segments.first { $0.kind == .fresh }?.fraction ?? 0) - 1.0) < 1e-9)
    }
}
