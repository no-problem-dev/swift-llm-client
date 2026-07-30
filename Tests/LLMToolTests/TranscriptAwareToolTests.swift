import Foundation
import Testing
import LLMClient
@testable import LLMTool

/// トランスクリプトを受け取って内容を記録するテスト用ツール。
private struct TranscriptProbeTool: TranscriptAwareTool {
    let recorder: TranscriptRecorder

    var toolName: String { "probe" }
    var toolDescription: String { "record transcript" }
    var inputSchema: JSONSchema {
        .object(properties: ["x": .string()], required: [])
    }

    func execute(with argumentsData: Data) async throws -> ToolResult {
        .text("plain")
    }

    func execute(with argumentsData: Data, transcript: [LLMMessage]) async throws -> ToolResult {
        await recorder.record(transcript)
        return .text("aware")
    }
}

private actor TranscriptRecorder {
    var transcripts: [[LLMMessage]] = []
    func record(_ transcript: [LLMMessage]) { transcripts.append(transcript) }
}

private struct PlainTool: Tool {
    var toolName: String { "plain" }
    var toolDescription: String { "no transcript" }
    var inputSchema: JSONSchema {
        .object(properties: ["x": .string()], required: [])
    }

    func execute(with argumentsData: Data) async throws -> ToolResult {
        .text("ok")
    }
}

@Suite("TranscriptAwareTool")
struct TranscriptAwareToolTests {

    @Test("準拠ツールにはトランスクリプトが渡り、aware 側の execute が呼ばれる")
    func passesTranscriptToAwareTool() async throws {
        let recorder = TranscriptRecorder()
        let tools = ToolSet(tools: [TranscriptProbeTool(recorder: recorder)])
        let transcript: [LLMMessage] = [
            .user("鶏むね肉のレシピ"),
            .toolUses([(id: "c1", name: "search_recipes", input: Data("{}".utf8))]),
            .toolResults([(toolCallId: "c1", name: "search_recipes", content: .success(#"{"recipes":[]}"#))]),
        ]

        let result = try await tools.execute(toolNamed: "probe", with: Data("{}".utf8), transcript: transcript)

        #expect(result.stringValue == "aware")
        let recorded = try #require(await recorder.transcripts.first)
        #expect(recorded.count == 3)
    }

    @Test("非準拠ツールは transcript 付き経路でも通常どおり実行される")
    func fallsBackForPlainTool() async throws {
        let tools = ToolSet(tools: [PlainTool()])
        let result = try await tools.execute(toolNamed: "plain", with: Data("{}".utf8), transcript: [.user("hi")])
        #expect(result.stringValue == "ok")
    }

    @Test("transcript 付き経路でもスキーマ coercion が効く")
    func coercesArgumentsOnTranscriptPath() async throws {
        let recorder = TranscriptRecorder()
        let tools = ToolSet(tools: [TranscriptProbeTool(recorder: recorder)])
        // 引数は不正でなければそのまま通る（coercion 経路の疎通確認）
        let result = try await tools.execute(
            toolNamed: "probe",
            with: Data(#"{"x":"value"}"#.utf8),
            transcript: []
        )
        #expect(result.stringValue == "aware")
    }
}
