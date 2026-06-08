import Foundation
import Testing
import LLMClient
@testable import LLMTool

@Suite("ToolArgumentCoercion")
struct ToolArgumentCoercionTests {

    private let schema = JSONSchema.object(
        properties: [
            "query": .string(description: "q"),
            "max_results": .integer(description: "n"),
            "ratio": .number(description: "r"),
            "verbose": .boolean(description: "v"),
        ],
        required: ["query"]
    )

    private func coerced(_ json: String) -> [String: Any] {
        let data = schema.coerceArguments(Data(json.utf8))
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    @Test("文字列の整数を Int へ強制する")
    func coercesStringInteger() {
        let r = coerced(#"{"query":"swift","max_results":"10"}"#)
        #expect(r["max_results"] as? Int == 10)
        #expect(r["query"] as? String == "swift")
    }

    @Test("文字列の小数を Double へ、文字列の真偽値を Bool へ")
    func coercesNumberAndBool() {
        let r = coerced(#"{"query":"x","ratio":"0.5","verbose":"true"}"#)
        #expect(r["ratio"] as? Double == 0.5)
        #expect(r["verbose"] as? Bool == true)
    }

    @Test("正しい型はそのまま保持する")
    func leavesValidTypesUntouched() {
        let r = coerced(#"{"query":"x","max_results":3,"verbose":false}"#)
        #expect(r["max_results"] as? Int == 3)
        #expect(r["verbose"] as? Bool == false)
    }

    @Test("数値に変換できない文字列はそのまま（壊さない）")
    func leavesNonNumericString() {
        let r = coerced(#"{"query":"x","max_results":"abc"}"#)
        #expect(r["max_results"] as? String == "abc")
    }

    @Test("string フィールドの数値文字列は変換しない")
    func doesNotTouchStringField() {
        let r = coerced(#"{"query":"123"}"#)
        #expect(r["query"] as? String == "123")
    }

    @Test("デコードまで通ること（型不一致エラーが消える）")
    func decodesAfterCoercion() throws {
        struct Input: Codable {
            var query: String
            var maxResults: Int?
            enum CodingKeys: String, CodingKey { case query; case maxResults = "max_results" }
        }
        // web_search 実装と同じく素の JSONDecoder + 明示 CodingKeys。
        let data = schema.coerceArguments(Data(#"{"query":"x","max_results":"7"}"#.utf8))
        let input = try JSONDecoder().decode(Input.self, from: data)
        #expect(input.maxResults == 7)
    }
}
