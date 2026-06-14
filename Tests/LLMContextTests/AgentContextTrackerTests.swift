import Testing
import Foundation
@testable import LLMContext
@testable import LLMTool
@testable import LLMClient

@MainActor
@Suite("AgentContextTracker host/A2 集約")
struct AgentContextTrackerTests {

    private func tool(_ name: String, _ desc: String) -> DynamicTool {
        DynamicTool(name, description: desc) {
            JSONSchema.string(description: "a").named("a")
        } handler: { _ in .text("ok") }
    }

    // MARK: - T4-1: ライブ占有

    @Test("record(usage, profile) で占有を更新")
    func recordOccupancy() {
        let tracker = AgentContextTracker(counter: MockCounter(wrapper: 0))
        let profile = ModelProfile(
            summary: "s", modelFamily: "Claude",
            contextWindow: 1_000_000, maxOutputTokens: 64_000,
            toolCallSupport: .excellent, japaneseSupport: .excellent, modalities: [.text]
        )
        tracker.record(agentID: "host", usage: TokenUsage(inputTokens: 142_000, outputTokens: 10), profile: profile)

        let r = tracker.report(for: "host")
        #expect(r?.occupancy.used == 142_000)
        #expect(r?.occupancy.windowSize == 1_000_000)
        #expect(r?.occupancy.free == 1_000_000 - 142_000 - 64_000) // reserve = maxOutputTokens
        #expect(r?.breakdown == nil)
    }

    // MARK: - T4-2: host と A2 を独立追跡

    @Test("host と複数 A2 を独立に保持")
    func independentAgents() {
        let tracker = AgentContextTracker(counter: MockCounter(wrapper: 0))
        tracker.record(agentID: "host", usage: TokenUsage(inputTokens: 100_000, outputTokens: 0), windowSize: 1_000_000)
        tracker.record(agentID: "A2-researcher", usage: TokenUsage(inputTokens: 30_000, outputTokens: 0), windowSize: 200_000)

        #expect(tracker.report(for: "host")?.occupancy.used == 100_000)
        #expect(tracker.report(for: "host")?.occupancy.windowSize == 1_000_000)
        #expect(tracker.report(for: "A2-researcher")?.occupancy.used == 30_000)
        #expect(tracker.report(for: "A2-researcher")?.occupancy.windowSize == 200_000)
        #expect(tracker.reports.count == 2)
    }

    // MARK: - T4-3: 占有(usage) + 内訳(count_tokens) を 1 レポートに

    @Test("record の後 refreshBreakdown で占有を保持しつつ内訳を付与")
    func occupancyPlusBreakdown() async throws {
        let tracker = AgentContextTracker(counter: MockCounter(wrapper: 340))
        tracker.record(agentID: "host", usage: TokenUsage(inputTokens: 120_000, outputTokens: 0), windowSize: 1_000_000)

        let sys = "You are helpful."
        let groups = [ToolGroup(segment: .toolDefinitions, tools: ToolSet(tools: [tool("t", "desc")]))]
        let bd = try await tracker.refreshBreakdown(
            agentID: "host", modelID: "claude-sonnet-4-6",
            systemPrompt: sys, messages: [LLMMessage.user("hi")], toolGroups: groups
        )

        let r = tracker.report(for: "host")
        #expect(r?.occupancy.used == 120_000)            // usage 由来を保持
        #expect(r?.breakdown != nil)
        #expect(r?.breakdown?.tokens(for: .systemPrompt) == sys.count)
        #expect(r?.breakdown?.isConsistent == true)
        #expect(bd.totalMeasured == r?.breakdown?.totalMeasured)
    }

    // MARK: - per-agent キャッシュの独立性

    @Test("per-agent キャッシュ: 同一 agent のメッセージのみ変化は bare 1 回、別 agent は別キャッシュ")
    func perAgentCacheIsolation() async throws {
        let counter = MockCounter(wrapper: 340)
        let tracker = AgentContextTracker(counter: counter)
        let sys = "S"
        let groups = [ToolGroup(segment: .toolDefinitions, tools: ToolSet(tools: [tool("t", "d")]))]

        // host 初回: フル ladder = 3
        _ = try await tracker.refreshBreakdown(agentID: "host", modelID: "claude-sonnet-4-6", systemPrompt: sys, messages: [LLMMessage.user("m1")], toolGroups: groups)
        let c1 = await counter.callCount
        #expect(c1 == 3)

        // host メッセージのみ変化: +1
        _ = try await tracker.refreshBreakdown(agentID: "host", modelID: "claude-sonnet-4-6", systemPrompt: sys, messages: [LLMMessage.user("m2 longer")], toolGroups: groups)
        let c2 = await counter.callCount
        #expect(c2 - c1 == 1)

        // A2 初回: 別キャッシュなのでフル ladder = +3
        _ = try await tracker.refreshBreakdown(agentID: "A2", modelID: "claude-sonnet-4-6", systemPrompt: sys, messages: [LLMMessage.user("m1")], toolGroups: groups)
        let c3 = await counter.callCount
        #expect(c3 - c2 == 3)
    }
}
