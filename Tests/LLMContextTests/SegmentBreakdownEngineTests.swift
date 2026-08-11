import Testing
import Foundation
@testable import LLMContext
@testable import LLMTool
@testable import LLMClient

// MARK: - Mock TokenCounting

/// 決定論モック: count = wrapper + system長 + Σtool(name+desc)長 + Σmessage text長。
///
/// wrapper は **全呼び出しに含まれる per-request overhead** を模す。これにより
/// 「単独カウント合算は wrapper を N 重計上する」という現実の罠を再現でき、
/// 差分減算がそれを相殺することを検証できる。
actor MockCounter: TokenCounting {
    let wrapper: Int
    private(set) var callCount = 0

    init(wrapper: Int) { self.wrapper = wrapper }

    func countInputTokens(
        modelID: String, systemPrompt: String?, messages: [LLMMessage], tools: ToolSet?
    ) async -> Int {
        callCount += 1
        let sys = systemPrompt?.count ?? 0
        let toolSize = tools?.tools.reduce(0) { $0 + toolSizeFn($1) } ?? 0
        let msgSize = messages.reduce(0) { $0 + messageSizeFn($1) }
        return wrapper + sys + toolSize + msgSize
    }
}

private func toolSizeFn(_ t: any Tool) -> Int { t.toolName.count + t.toolDescription.count }
private func messageSizeFn(_ m: LLMMessage) -> Int {
    m.contents.reduce(0) { acc, c in
        if case .text(let s) = c { return acc + s.count }
        return acc
    }
}

// MARK: - Fixtures

private func makeTool(_ name: String, _ desc: String) -> DynamicTool {
    DynamicTool(name, description: desc) {
        JSONSchema.string(description: "arg").named("arg")
    } handler: { _ in .text("ok") }
}

/// 名前も説明も同じで、引数スキーマだけが違うツール。
private func makeToolWithSchema(_ name: String, _ desc: String, argName: String) -> DynamicTool {
    DynamicTool(name, description: desc) {
        JSONSchema.string(description: "arg").named(argName)
    } handler: { _ in .text("ok") }
}

private let modelID = "claude-sonnet-4-6"

// MARK: - Tests

@Suite("SegmentBreakdownEngine 差分減算")
struct SegmentBreakdownEngineTests {

    // MARK: - T2-2: clean differential

    @Test("system / tools / history を wrapper 相殺の clean marginal で分割")
    func cleanDifferential() async throws {
        let wrapper = 340
        let engine = SegmentBreakdownEngine(counter: MockCounter(wrapper: wrapper))

        let sys = "You are a helpful assistant."
        let weather = makeTool("get_weather", "Get current weather")
        let tools = ToolSet(tools: [weather])
        let msgs = [LLMMessage.user("Hello world")]

        let bd = try await engine.breakdown(
            modelID: modelID, systemPrompt: sys, messages: msgs,
            toolGroups: [ToolGroup(segment: .toolDefinitions, tools: tools)]
        )

        let toolSize = weather.toolName.count + weather.toolDescription.count
        let msgSize = "Hello world".count

        #expect(bd.tokens(for: .systemPrompt) == sys.count)              // wrapper, msgs 相殺
        #expect(bd.tokens(for: .toolDefinitions) == toolSize)            // wrapper, sys, msgs 相殺
        #expect(bd.tokens(for: .conversationHistory) == wrapper + msgSize) // wrapper を内包
        #expect(bd.totalMeasured == wrapper + sys.count + toolSize + msgSize)
        #expect(bd.isConsistent) // Σ == total（T2-6）
    }

    // MARK: - T2-3: anti-3x bug（wrapper 二重計上の回避）

    @Test("marginal は単独カウントより wrapper 分だけ小さい（Claude Code 3x バグの回帰防止）")
    func differentialExcludesWrapper() async throws {
        let wrapper = 340
        let counter = MockCounter(wrapper: wrapper)
        let engine = SegmentBreakdownEngine(counter: counter)

        let sys = "System."
        let tool = makeTool("search", "Search the web")
        let tools = ToolSet(tools: [tool])
        let msgs = [LLMMessage.user("hi")]

        let bd = try await engine.breakdown(
            modelID: modelID, systemPrompt: sys, messages: msgs,
            toolGroups: [ToolGroup(segment: .toolDefinitions, tools: tools)]
        )

        // 単独カウント（= wrapper + tools + msgs を含む）。Claude Code はこれを合算していた。
        let isolatedTools = await counter.countInputTokens(
            modelID: modelID, systemPrompt: nil, messages: msgs, tools: tools
        )
        let toolSize = tool.toolName.count + tool.toolDescription.count
        let msgSize = "hi".count

        // 差分は純 tool サイズ、単独は wrapper+msgs を余分に含む
        #expect(bd.tokens(for: .toolDefinitions) == toolSize)
        #expect(isolatedTools == wrapper + toolSize + msgSize)
        #expect(isolatedTools - bd.tokens(for: .toolDefinitions) == wrapper + msgSize)

        // total には wrapper がちょうど 1 回（二重計上していない）
        #expect(bd.totalMeasured == wrapper + sys.count + toolSize + msgSize)
    }

    // MARK: - T2-4: MCP 分離

    @Test("builtin と MCP ツールを別セグメントへ累積差分で分割")
    func mcpSeparation() async throws {
        let engine = SegmentBreakdownEngine(counter: MockCounter(wrapper: 100))

        let builtinTool = makeTool("read_file", "Read a file")
        let mcpTool = makeTool("xcode_build", "Build the project via MCP")
        let builtin = ToolSet(tools: [builtinTool])
        let mcp = ToolSet(tools: [mcpTool])
        let msgs = [LLMMessage.user("go")]

        let bd = try await engine.breakdown(
            modelID: modelID, systemPrompt: "S", messages: msgs,
            toolGroups: [
                ToolGroup(segment: .toolDefinitions, tools: builtin),
                ToolGroup(segment: .mcpToolDefinitions, tools: mcp),
            ]
        )

        #expect(bd.tokens(for: .toolDefinitions) == builtinTool.toolName.count + builtinTool.toolDescription.count)
        #expect(bd.tokens(for: .mcpToolDefinitions) == mcpTool.toolName.count + mcpTool.toolDescription.count)
        #expect(bd.isConsistent)
    }

    // MARK: - エッジ: tools 無し / system 無し

    @Test("system も tools も無ければ bare（conversationHistory）のみ・1 回計測")
    func bareOnly() async throws {
        let counter = MockCounter(wrapper: 50)
        let engine = SegmentBreakdownEngine(counter: counter)
        let msgs = [LLMMessage.user("only messages")]

        let bd = try await engine.breakdown(
            modelID: modelID, systemPrompt: nil, messages: msgs, toolGroups: []
        )
        let msgSize = "only messages".count
        #expect(bd.tokens(for: .conversationHistory) == 50 + msgSize)
        #expect(bd.totalMeasured == 50 + msgSize)
        #expect(bd.isConsistent)
        #expect(await counter.callCount == 1)
    }
}

// MARK: - BreakdownCache（T2-5: 増分再計算）

@Suite("BreakdownCache 増分再計算")
struct BreakdownCacheTests {

    @Test("メッセージのみ変化なら bare 1 回のみ再計測し marginal を再利用")
    func messageOnlyChangeReusesMarginals() async throws {
        let counter = MockCounter(wrapper: 340)
        let cache = BreakdownCache(counter: counter)

        let sys = "You are helpful."
        let tool = makeTool("get_weather", "Weather")
        let groups = [ToolGroup(segment: .toolDefinitions, tools: ToolSet(tools: [tool]))]

        // 初回: フル ladder = bare + sysOnly + tool rung = 3 回
        let r1 = try await cache.breakdown(
            modelID: modelID, systemPrompt: sys, messages: [LLMMessage.user("first")], toolGroups: groups
        )
        let c1 = await counter.callCount
        #expect(c1 == 3)
        #expect(r1.isConsistent)

        // メッセージのみ変化（同一 sig）: bare のみ = +1 回
        let r2 = try await cache.breakdown(
            modelID: modelID, systemPrompt: sys, messages: [LLMMessage.user("second message longer")], toolGroups: groups
        )
        let c2 = await counter.callCount
        #expect(c2 - c1 == 1)

        let toolSize = tool.toolName.count + tool.toolDescription.count
        #expect(r2.tokens(for: .systemPrompt) == sys.count)       // 再利用された marginal
        #expect(r2.tokens(for: .toolDefinitions) == toolSize)     // 再利用された marginal
        #expect(r2.tokens(for: .conversationHistory) == 340 + "second message longer".count)
        #expect(r2.isConsistent)
    }

    @Test("system が変化したらフル ladder を再実行")
    func systemChangeRecomputes() async throws {
        let counter = MockCounter(wrapper: 340)
        let cache = BreakdownCache(counter: counter)
        let groups = [ToolGroup(segment: .toolDefinitions, tools: ToolSet(tools: [makeTool("t", "d")]))]

        _ = try await cache.breakdown(modelID: modelID, systemPrompt: "A", messages: [LLMMessage.user("m")], toolGroups: groups)
        let c1 = await counter.callCount // 3

        _ = try await cache.breakdown(modelID: modelID, systemPrompt: "DIFFERENT", messages: [LLMMessage.user("m")], toolGroups: groups)
        let c2 = await counter.callCount
        #expect(c2 - c1 == 3) // sig 変化 → フル ladder
    }

    // MARK: - 署名は「計測が依存しうるもの」を全部覆う

    @Test("引数スキーマだけ変えてもフル ladder を再実行する")
    func schemaChangeRecomputes() async throws {
        let counter = MockCounter(wrapper: 340)
        let cache = BreakdownCache(counter: counter)

        let before = [ToolGroup(
            segment: .toolDefinitions,
            tools: ToolSet(tools: [makeToolWithSchema("search", "Search the web", argName: "query")])
        )]
        // 名前も説明も同一。変えたのはスキーマのプロパティ名だけ。
        let after = [ToolGroup(
            segment: .toolDefinitions,
            tools: ToolSet(tools: [makeToolWithSchema("search", "Search the web", argName: "q")])
        )]

        _ = try await cache.breakdown(
            modelID: modelID, systemPrompt: "A", messages: [LLMMessage.user("m")], toolGroups: before
        )
        let c1 = await counter.callCount

        _ = try await cache.breakdown(
            modelID: modelID, systemPrompt: "A", messages: [LLMMessage.user("m")], toolGroups: after
        )
        let c2 = await counter.callCount
        #expect(c2 - c1 == 3)
    }

    @Test("モデルを切り替えたらフル ladder を再実行する")
    func modelChangeRecomputes() async throws {
        let counter = MockCounter(wrapper: 340)
        let cache = BreakdownCache(counter: counter)
        let groups = [ToolGroup(segment: .toolDefinitions, tools: ToolSet(tools: [makeTool("t", "d")]))]

        _ = try await cache.breakdown(
            modelID: "claude-sonnet-4-6", systemPrompt: "A", messages: [LLMMessage.user("m")], toolGroups: groups
        )
        let c1 = await counter.callCount

        _ = try await cache.breakdown(
            modelID: "gpt-5", systemPrompt: "A", messages: [LLMMessage.user("m")], toolGroups: groups
        )
        let c2 = await counter.callCount
        #expect(c2 - c1 == 3)
    }

    @Test("何も変えなければ従来どおり bare 1 回で済む")
    func unchangedInputsStillReuse() async throws {
        let counter = MockCounter(wrapper: 340)
        let cache = BreakdownCache(counter: counter)
        let groups = [ToolGroup(segment: .toolDefinitions, tools: ToolSet(tools: [makeTool("t", "d")]))]

        _ = try await cache.breakdown(
            modelID: modelID, systemPrompt: "A", messages: [LLMMessage.user("m")], toolGroups: groups
        )
        let c1 = await counter.callCount

        _ = try await cache.breakdown(
            modelID: modelID, systemPrompt: "A", messages: [LLMMessage.user("m2")], toolGroups: groups
        )
        let c2 = await counter.callCount
        #expect(c2 - c1 == 1)
    }
}
