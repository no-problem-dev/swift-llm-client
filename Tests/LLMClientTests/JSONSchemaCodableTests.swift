import Testing
import Foundation
@testable import LLMClient

@Suite("JSONSchema Codable")
struct JSONSchemaCodableTests {

    /// Encodable で出した JSON を Decodable で読み戻し、構造が一致することを確認する。
    @Test func roundTripsNestedObjectSchema() throws {
        let schema = JSONSchema.object(
            description: "User",
            properties: [
                "name": .string(description: "名前"),
                "age": .integer(minimum: 0, maximum: 150),
                "tags": .array(description: "タグ", items: .string()),
                "role": .enum(["admin", "user"], description: "役割"),
            ],
            required: ["name", "age"]
        )

        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)

        #expect(decoded == schema)
    }

    /// 標準 JSON Schema 文字列から直接デコードできることを確認する。
    @Test func decodesFromRawJSONSchema() throws {
        let json = """
        {
          "type": "object",
          "properties": {
            "query": { "type": "string", "description": "検索語" },
            "limit": { "type": "integer" }
          },
          "required": ["query"]
        }
        """
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: Data(json.utf8))

        #expect(decoded.type == .object)
        #expect(decoded.properties?["query"]?.type == .string)
        #expect(decoded.properties?["query"]?.description == "検索語")
        #expect(decoded.properties?["limit"]?.type == .integer)
        #expect(decoded.required == ["query"])
    }

    /// type 省略時は object として扱う（寛容なデコード）。
    @Test func defaultsToObjectWhenTypeMissing() throws {
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: Data("{}".utf8))
        #expect(decoded.type == .object)
    }

    /// nullable は type を ["<type>","null"] union として出力する。
    @Test func nullableEncodesAsTypeUnion() throws {
        let schema = JSONSchema(type: .string, nullable: true, description: "maybe")
        let json = try schema.toJSONString()
        #expect(json.contains("[\"string\",\"null\"]"))
        #expect(!json.contains("\"type\":\"string\""))
    }

    /// nullable union を読み戻すと nullable=true + 主型が復元される。
    @Test func decodesNullableTypeUnion() throws {
        let json = #"{"type":["integer","null"]}"#
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: Data(json.utf8))
        #expect(decoded.type == .integer)
        #expect(decoded.nullable == true)
    }

    /// 非 nullable は単一文字列のまま round-trip する。
    @Test func nonNullableRoundTrips() throws {
        let schema = JSONSchema(type: .string, nullable: false)
        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)
        #expect(decoded.nullable == false)
        #expect(decoded.type == .string)
        #expect(decoded == schema)
    }
}
