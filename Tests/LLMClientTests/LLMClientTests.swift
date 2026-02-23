import Testing
@testable import LLMClient

@Test func testLLMResponseText() {
    let response = LLMResponse(
        content: [.text("Hello"), .text(" World")],
        model: "test-model",
        usage: TokenUsage(inputTokens: 10, outputTokens: 5)
    )
    #expect(response.text == "Hello World")
    #expect(response.usage.totalTokens == 15)
}

@Test func testLLMMessageFactory() {
    let userMsg = LLMMessage.user("test")
    #expect(userMsg.role == .user)
    #expect(userMsg.content == "test")

    let assistantMsg = LLMMessage.assistant("reply")
    #expect(assistantMsg.role == .assistant)
    #expect(assistantMsg.content == "reply")
}
