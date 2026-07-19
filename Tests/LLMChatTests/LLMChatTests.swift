import Foundation
import Testing
@testable import LLMChat
import LLMClient

// MARK: - Test Fixtures

/// テスト用の構造化出力型（マクロ非依存で手動準拠）
private struct EchoOutput: StructuredProtocol, Equatable {
    var text: String

    static var jsonSchema: JSONSchema {
        JSONSchema(
            type: .object,
            properties: ["text": JSONSchema(type: .string)],
            required: ["text"],
            additionalProperties: false
        )
    }
}

/// テスト用のモッククライアント（実 API は叩かない）
private struct MockChatClient: ChatCapableClient {
    typealias Model = String

    enum Behavior: Sendable {
        case success(json: String)
        case failure(LLMError)
    }

    let behavior: Behavior

    func chat<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ChatResponse<T> {
        switch behavior {
        case .success(let json):
            let result = try JSONDecoder().decode(T.self, from: Data(json.utf8))
            return ChatResponse(
                result: result,
                assistantMessage: .assistant(json),
                usage: TokenUsage(inputTokens: 10, outputTokens: 5),
                stopReason: .endTurn,
                model: model,
                rawText: json
            )
        case .failure(let error):
            throw error
        }
    }

    func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: SystemPrompt?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T> {
        throw LLMError.emptyResponse
    }

    func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T> {
        throw LLMError.emptyResponse
    }
}

// MARK: - ConversationHistory: 基本状態

@Suite("ConversationHistory 基本状態")
struct ConversationHistoryStateTests {

    @Test("空の履歴はメッセージ 0・ターン 0・使用量 0")
    func emptyHistory() async {
        let history = ConversationHistory()
        #expect(await history.getMessages().isEmpty)
        #expect(await history.turnCount == 0)
        #expect(await history.getTotalUsage().totalTokens == 0)
    }

    @Test("既存メッセージからの初期化はターン数を復元する（ツール結果は数えない）")
    func initFromExistingMessages() async {
        let messages: [LLMMessage] = [
            .user("こんにちは"),
            .assistant("こんにちは！"),
            .user("天気は？"),
            .toolResult(toolCallId: "call_1", name: "get_weather", content: "晴れ"),
        ]
        let history = ConversationHistory(messages: messages)
        #expect(await history.getMessages().count == 4)
        // .toolResult は user ロールだがターンには数えない
        #expect(await history.turnCount == 2)
    }

    @Test("既存メッセージ + 使用量からの初期化は使用量を引き継ぐ")
    func initFromMessagesAndUsage() async {
        let history = ConversationHistory(
            messages: [.user("hi")],
            totalUsage: TokenUsage(inputTokens: 100, outputTokens: 50)
        )
        let usage = await history.getTotalUsage()
        #expect(usage.inputTokens == 100)
        #expect(usage.outputTokens == 50)
    }
}

// MARK: - ConversationHistory: 追加・ターン・使用量・クリア

@Suite("ConversationHistory 追加とターン管理")
struct ConversationHistoryAppendTests {

    @Test("append はメッセージを時系列順に保持する")
    func appendPreservesOrder() async {
        let history = ConversationHistory()
        await history.append(.user("Q1"))
        await history.append(.assistant("A1"))
        await history.append(.user("Q2"))

        let messages = await history.getMessages()
        #expect(messages.map(\.content) == ["Q1", "A1", "Q2"])
        #expect(messages.map(\.role) == [.user, .assistant, .user])
    }

    @Test("ユーザーメッセージのみターン数を増やす")
    func onlyUserMessagesCountAsTurns() async {
        let history = ConversationHistory()
        await history.append(.user("Q1"))
        #expect(await history.turnCount == 1)

        await history.append(.assistant("A1"))
        #expect(await history.turnCount == 1)

        // ツール呼び出し（assistant）とツール結果（user ロールだがツール応答）は数えない
        await history.append(.toolUse(id: "call_1", name: "search", input: Data("{}".utf8)))
        await history.append(.toolResult(toolCallId: "call_1", name: "search", content: "結果"))
        #expect(await history.turnCount == 1)

        await history.append(.user("Q2"))
        #expect(await history.turnCount == 2)
    }

    @Test("addUsage は入出力トークンを累積する")
    func addUsageAccumulates() async {
        let history = ConversationHistory()
        await history.addUsage(TokenUsage(inputTokens: 100, outputTokens: 20))
        await history.addUsage(TokenUsage(inputTokens: 300, outputTokens: 50))

        let usage = await history.getTotalUsage()
        #expect(usage.inputTokens == 400)
        #expect(usage.outputTokens == 70)
        #expect(usage.totalTokens == 470)
    }

    @Test("clear はメッセージと使用量をリセットする")
    func clearResetsMessagesAndUsage() async {
        let history = ConversationHistory()
        await history.append(.user("Q1"))
        await history.addUsage(TokenUsage(inputTokens: 10, outputTokens: 5))

        await history.clear()

        #expect(await history.getMessages().isEmpty)
        #expect(await history.getTotalUsage().totalTokens == 0)
    }
}

// MARK: - ConversationHistory: 孤立 tool_use の修復

@Suite("ConversationHistory 孤立 tool_use の修復")
struct ConversationHistorySanitizeTests {

    @Test("末尾の孤立 tool_use には合成 tool_result が挿入される")
    func orphanedToolUseAtTailIsRepaired() async {
        let history = ConversationHistory()
        await history.append(.user("天気は？"))
        await history.append(.toolUse(id: "call_1", name: "get_weather", input: Data("{}".utf8)))

        let messages = await history.getMessages()
        #expect(messages.count == 3)

        let synthetic = messages[2]
        #expect(synthetic.role == .user)
        #expect(synthetic.hasToolResult)
        #expect(synthetic.toolResults.map(\.toolCallId) == ["call_1"])
    }

    @Test("一部だけ tool_result がある場合は不足分だけ合成される")
    func partiallyMissingToolResultsAreMerged() async {
        let history = ConversationHistory()
        await history.append(.user("調べて"))
        await history.append(.toolUses([
            (id: "call_1", name: "search", input: Data("{}".utf8)),
            (id: "call_2", name: "search", input: Data("{}".utf8)),
        ]))
        await history.append(.toolResult(toolCallId: "call_1", name: "search", content: "結果1"))

        let messages = await history.getMessages()
        // 既存の user メッセージに不足分がマージされる（メッセージ数は増えない）
        #expect(messages.count == 3)

        let resultIds = Set(messages[2].toolResults.map(\.toolCallId))
        #expect(resultIds == ["call_1", "call_2"])
    }

    @Test("tool_use と tool_result が揃っている履歴は変更されない")
    func completeToolPairsAreUntouched() async {
        let history = ConversationHistory()
        await history.append(.user("調べて"))
        await history.append(.toolUse(id: "call_1", name: "search", input: Data("{}".utf8)))
        await history.append(.toolResult(toolCallId: "call_1", name: "search", content: "結果"))
        await history.append(.assistant("結果はこちらです"))

        let messages = await history.getMessages()
        #expect(messages.count == 4)
        #expect(messages[3].content == "結果はこちらです")
    }
}

// MARK: - ConversationHistory: イベントストリーム

@Suite("ConversationHistory イベントストリーム")
struct ConversationHistoryEventTests {

    @Test("操作の種類に応じたイベントが順序どおり配信される")
    func eventsAreDeliveredInOrder() async {
        let history = ConversationHistory()

        await history.append(.user("Q1"))
        await history.append(.assistant("A1"))
        await history.append(.toolUse(id: "call_1", name: "search", input: Data("{}".utf8)))
        await history.append(.toolResult(toolCallId: "call_1", name: "search", content: "結果"))
        await history.addUsage(TokenUsage(inputTokens: 10, outputTokens: 5))
        await history.clear()
        await history.emitError(.rateLimitExceeded)

        var events: [ConversationEvent] = []
        for await event in history.eventStream {
            events.append(event)
            if events.count == 7 { break }
        }

        guard case .userMessage(let user) = events[0] else {
            Issue.record("events[0] は .userMessage であるべき: \(events[0])")
            return
        }
        #expect(user.content == "Q1")

        guard case .assistantMessage(let assistant) = events[1] else {
            Issue.record("events[1] は .assistantMessage であるべき: \(events[1])")
            return
        }
        #expect(assistant.content == "A1")

        guard case .toolCallMessage = events[2] else {
            Issue.record("events[2] は .toolCallMessage であるべき: \(events[2])")
            return
        }
        guard case .toolResultMessage = events[3] else {
            Issue.record("events[3] は .toolResultMessage であるべき: \(events[3])")
            return
        }
        guard case .usageUpdated(let usage) = events[4] else {
            Issue.record("events[4] は .usageUpdated であるべき: \(events[4])")
            return
        }
        #expect(usage.totalTokens == 15)

        guard case .cleared = events[5] else {
            Issue.record("events[5] は .cleared であるべき: \(events[5])")
            return
        }
        guard case .error(.rateLimitExceeded) = events[6] else {
            Issue.record("events[6] は .error(.rateLimitExceeded) であるべき: \(events[6])")
            return
        }
    }
}

// MARK: - ChatCapableClient + ConversationHistory の連携

@Suite("ChatCapableClient 会話フロー")
struct ChatConversationFlowTests {

    @Test("成功時: ユーザー・アシスタント両方が履歴に追加され使用量が累積される")
    func successAppendsBothMessagesAndUsage() async throws {
        let client = MockChatClient(behavior: .success(json: #"{"text": "こんにちは"}"#))
        let history = ConversationHistory()

        let result: EchoOutput = try await client.chat(
            input: "挨拶して",
            history: history,
            model: "mock-model"
        )

        #expect(result == EchoOutput(text: "こんにちは"))

        let messages = await history.getMessages()
        #expect(messages.count == 2)
        #expect(messages[0].role == .user)
        // LLMInput.toLLMMessage() はテキストを <context> タグで包む
        #expect(messages[0].content.contains("挨拶して"))
        #expect(messages[1].role == .assistant)

        let usage = await history.getTotalUsage()
        #expect(usage.inputTokens == 10)
        #expect(usage.outputTokens == 5)
        #expect(await history.turnCount == 1)
    }

    @Test("chatWithDetails はメタ情報付きレスポンスを返し履歴も更新する")
    func chatWithDetailsReturnsMetadata() async throws {
        let client = MockChatClient(behavior: .success(json: #"{"text": "詳細"}"#))
        let history = ConversationHistory()

        let response: ChatResponse<EchoOutput> = try await client.chatWithDetails(
            input: "詳細を教えて",
            history: history,
            model: "mock-model"
        )

        #expect(response.result == EchoOutput(text: "詳細"))
        #expect(response.model == "mock-model")
        #expect(response.stopReason == .endTurn)
        #expect(response.rawText == #"{"text": "詳細"}"#)
        #expect(await history.getMessages().count == 2)
    }

    @Test("失敗時: LLMError がそのまま伝播し、アシスタントは履歴に追加されない")
    func failurePropagatesErrorAndKeepsHistoryClean() async {
        let client = MockChatClient(behavior: .failure(.rateLimitExceeded))
        let history = ConversationHistory()

        await #expect(throws: LLMError.self) {
            let _: EchoOutput = try await client.chat(
                input: "挨拶して",
                history: history,
                model: "mock-model"
            )
        }

        // ユーザーメッセージだけが残る（アシスタントは追加されない）
        let messages = await history.getMessages()
        #expect(messages.count == 1)
        #expect(messages[0].role == .user)
        #expect(await history.getTotalUsage().totalTokens == 0)

        // エラーイベントが配信される
        var received: ConversationEvent?
        for await event in history.eventStream {
            if case .error = event {
                received = event
                break
            }
        }
        guard case .error(.rateLimitExceeded) = received else {
            Issue.record("受信イベントは .error(.rateLimitExceeded) であるべき: \(String(describing: received))")
            return
        }
    }

    @Test("複数ターンの会話で履歴が積み上がる")
    func multiTurnConversationAccumulates() async throws {
        let client = MockChatClient(behavior: .success(json: #"{"text": "応答"}"#))
        let history = ConversationHistory()

        let _: EchoOutput = try await client.chat(input: "1回目", history: history, model: "m")
        let _: EchoOutput = try await client.chat(input: "2回目", history: history, model: "m")

        #expect(await history.getMessages().count == 4)
        #expect(await history.turnCount == 2)
        let usage = await history.getTotalUsage()
        #expect(usage.inputTokens == 20)
        #expect(usage.outputTokens == 10)
    }
}
