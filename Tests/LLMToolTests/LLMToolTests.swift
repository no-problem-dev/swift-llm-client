import Testing
@testable import LLMTool
import LLMClient

@Test func testToolSetEmpty() {
    let toolSet = ToolSet()
    #expect(toolSet.isEmpty)
    #expect(toolSet.count == 0)
}
