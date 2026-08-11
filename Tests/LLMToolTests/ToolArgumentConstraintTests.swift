import Foundation
import Testing
@testable import LLMTool
import LLMClient

// MARK: - 背景
//
// @ToolArgument の制約は解析されたあと捨てられていた。generateArgumentsType が
// @StructuredField へ説明しか転記しなかったため、.minimum(1) や .enum([...]) は
// モデルに見せる inputSchema に載らなかった（ドキュメントは載ると書いていた）。
//
// マクロ展開そのものは LLMMacrosTests が文字列で押さえる。ここは展開後の型から
// 実際に組み上がる JSONSchema を見て、制約が最終成果物まで届くことを押さえる。

@Tool("在庫を検索する", name: "search_stock")
private struct SearchStockTool {
    @ToolArgument("検索語", .minLength(1), .maxLength(100))
    var keyword: String

    @ToolArgument("最大件数", .minimum(1), .maximum(100))
    var limit: Int

    @ToolArgument("並び順", .enum(["relevance", "price_asc", "price_desc"]))
    var sortBy: String

    @ToolArgument("連絡先", .format(.email))
    var contact: String

    @ToolArgument("タグ", .minItems(1), .maxItems(5))
    var tags: [String]

    func call() async throws -> String { "ok" }
}

@Suite("@ToolArgument の制約は inputSchema に載る")
struct ToolArgumentConstraintTests {

    private func property(_ name: String) throws -> JSONSchema {
        let schema = SearchStockTool().inputSchema
        return try #require(schema.properties?[name])
    }

    @Test("文字列長の制約が載る")
    func stringLengthConstraints() throws {
        let keyword = try property("keyword")
        #expect(keyword.description == "検索語")
        #expect(keyword.minLength == 1)
        #expect(keyword.maxLength == 100)
    }

    @Test("数値の下限・上限が載る")
    func numericBounds() throws {
        let limit = try property("limit")
        #expect(limit.type == .integer)
        #expect(limit.minimum == 1)
        #expect(limit.maximum == 100)
    }

    @Test("enum の候補が載る")
    func enumValues() throws {
        let sortBy = try property("sort_by")
        #expect(sortBy.enum == ["relevance", "price_asc", "price_desc"])
    }

    @Test("format が JSON Schema の綴りで載る")
    func formatValue() throws {
        let contact = try property("contact")
        #expect(contact.format == "email")
    }

    @Test("配列の要素数制約が載る")
    func arrayBounds() throws {
        let tags = try property("tags")
        #expect(tags.type == .array)
        #expect(tags.minItems == 1)
        #expect(tags.maxItems == 5)
    }

    @Test("制約を書いていない場合は説明だけが載る")
    func noConstraintsStillCarriesDescription() throws {
        let keyword = try property("keyword")
        #expect(keyword.type == .string)
        #expect(keyword.pattern == nil)
    }
}
