import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// マクロ実装はホストプラットフォーム向けビルドでのみ利用可能。
// クロスコンパイル（iOS 実機/シミュレータ等）では expansion テストをスキップする。
#if canImport(LLMMacros)
import LLMMacros

private let testMacros: [String: Macro.Type] = [
    "Structured": StructuredMacro.self,
    "StructuredField": StructuredFieldMacro.self,
    "StructuredEnum": StructuredEnumMacro.self,
    "StructuredCase": StructuredCaseMacro.self,
    "Tool": ToolMacro.self,
    "ToolArgument": ToolArgumentMacro.self,
    "ToolExclude": ToolExcludeMacro.self,
]

// MARK: - @Structured

final class StructuredMacroTests: XCTestCase {

    func testBasicStructGeneratesJSONSchemaAndConformance() {
        assertMacroExpansion(
            """
            @Structured("人物")
            struct Person {
                let name: String
                let age: Int?
            }
            """,
            expandedSource: """
            struct Person {
                let name: String
                let age: Int?

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,
                        description: "人物",
                        properties: [
                            "name": JSONSchema(type: .string),
                            "age": JSONSchema(type: .integer)
                        ],
                        required: ["name"],
                        additionalProperties: false
                    )
                }
            }

            extension Person: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    func testStructuredFieldDescriptionAndConstraints() {
        assertMacroExpansion(
            """
            @Structured
            struct Query {
                @StructuredField("検索語", .minLength(1), .maxLength(100))
                var keyword: String
                @StructuredField("タグ一覧", .minItems(1))
                var tags: [String]
            }
            """,
            expandedSource: """
            struct Query {
                var keyword: String
                var tags: [String]

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "keyword": JSONSchema(type: .string, description: "検索語", minLength: 1, maxLength: 100),
                            "tags": JSONSchema(type: .array, description: "タグ一覧", items: JSONSchema(type: .string), minItems: 1)
                        ],
                        required: ["keyword", "tags"],
                        additionalProperties: false
                    )
                }
            }

            extension Query: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    func testCamelCasePropertyIsConvertedToSnakeCase() {
        assertMacroExpansion(
            """
            @Structured
            struct Profile {
                var userName: String
            }
            """,
            expandedSource: """
            struct Profile {
                var userName: String

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "user_name": JSONSchema(type: .string)
                        ],
                        required: ["user_name"],
                        additionalProperties: false
                    )
                }
            }

            extension Profile: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    func testNestedStructuredTypeReferencesItsSchema() {
        assertMacroExpansion(
            """
            @Structured
            struct Order {
                var item: Product
                var relatedItems: [Product]
            }
            """,
            expandedSource: """
            struct Order {
                var item: Product
                var relatedItems: [Product]

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .object,

                        properties: [
                            "item": Product.jsonSchema,
                            "related_items": JSONSchema(type: .array, items: Product.jsonSchema)
                        ],
                        required: ["item", "related_items"],
                        additionalProperties: false
                    )
                }
            }

            extension Order: StructuredProtocol, Codable, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    func testDiagnosticWhenAppliedToEnum() {
        assertMacroExpansion(
            """
            @Structured
            enum NotAStruct {
                case a
            }
            """,
            expandedSource: """
            enum NotAStruct {
                case a
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Structured can only be applied to structs",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }
}

// MARK: - @StructuredField（マーカー peer マクロ）

final class StructuredFieldMacroTests: XCTestCase {

    func testStandaloneFieldExpandsToNothing() {
        assertMacroExpansion(
            """
            struct Plain {
                @StructuredField("説明")
                var value: String
            }
            """,
            expandedSource: """
            struct Plain {
                var value: String
            }
            """,
            macros: testMacros
        )
    }

    func testDiagnosticWhenAppliedToFunction() {
        assertMacroExpansion(
            """
            struct Plain {
                @StructuredField("説明")
                func notAProperty() {
                }
            }
            """,
            expandedSource: """
            struct Plain {
                func notAProperty() {
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StructuredField can only be applied to properties",
                    line: 2,
                    column: 5
                ),
            ],
            macros: testMacros
        )
    }
}

// MARK: - @StructuredEnum

final class StructuredEnumMacroTests: XCTestCase {

    /// `@StructuredCase` の説明がスキーマの description に畳み込まれること。
    ///
    /// 以前は enumDescription という誰も読まない別プロパティに入るだけで、スキーマには
    /// 生の raw value しか載らなかった。JSON Schema には enum の各値に説明を付ける場所が
    /// 無いので、description に畳むのが唯一モデルへ届く経路。
    func testStructuredCaseDescriptionsFoldIntoSchemaDescription() {
        assertMacroExpansion(
            """
            @StructuredEnum("優先度")
            enum Priority: String {
                @StructuredCase("低い")
                case low
                case high = "H"
            }
            """,
            expandedSource: """
            enum Priority: String {
                case low
                case high = "H"

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        description: "優先度. low: 低い", enum: ["low", "H"]
                    )
                }
            }

            extension Priority: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    /// 説明の無い enum は従来どおり description 無しのスキーマになる。
    func testEnumWithoutAnyDescriptionOmitsDescription() {
        assertMacroExpansion(
            """
            @StructuredEnum
            enum Status: String {
                case active
                case inactive
            }
            """,
            expandedSource: """
            enum Status: String {
                case active
                case inactive

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        enum: ["active", "inactive"]
                    )
                }
            }

            extension Status: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    /// enum 自体に説明が無くても、ケースの説明だけで description が立つ。
    func testCaseDescriptionsAloneProduceDescription() {
        assertMacroExpansion(
            """
            @StructuredEnum
            enum Status: String {
                @StructuredCase("使用中")
                case active
                @StructuredCase("停止中")
                case inactive
            }
            """,
            expandedSource: """
            enum Status: String {
                case active
                case inactive

                public static var jsonSchema: JSONSchema {
                    JSONSchema(
                        type: .string,
                        description: "active: 使用中; inactive: 停止中", enum: ["active", "inactive"]
                    )
                }
            }

            extension Status: StructuredProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    func testDiagnosticWhenAppliedToStruct() {
        assertMacroExpansion(
            """
            @StructuredEnum
            struct NotAnEnum {
            }
            """,
            expandedSource: """
            struct NotAnEnum {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StructuredEnum can only be applied to enums",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    func testDiagnosticWhenRawValueIsNotString() {
        assertMacroExpansion(
            """
            @StructuredEnum
            enum Level: Int {
                case one = 1
            }
            """,
            expandedSource: """
            enum Level: Int {
                case one = 1
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StructuredEnum requires enum with String raw value",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    func testDiagnosticWhenEnumHasNoCases() {
        assertMacroExpansion(
            """
            @StructuredEnum
            enum Empty: String {
            }
            """,
            expandedSource: """
            enum Empty: String {
            }

            extension Empty: StructuredProtocol, Sendable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StructuredEnum requires at least one case",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }
}

// MARK: - @StructuredCase（マーカー peer マクロ）

final class StructuredCaseMacroTests: XCTestCase {

    func testStandaloneCaseExpandsToNothing() {
        assertMacroExpansion(
            """
            enum Plain: String {
                @StructuredCase("説明")
                case a
            }
            """,
            expandedSource: """
            enum Plain: String {
                case a
            }
            """,
            macros: testMacros
        )
    }

    func testDiagnosticWhenAppliedToProperty() {
        assertMacroExpansion(
            """
            struct Plain {
                @StructuredCase("説明")
                var value: String
            }
            """,
            expandedSource: """
            struct Plain {
                var value: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StructuredCase can only be applied to enum cases",
                    line: 2,
                    column: 5
                ),
            ],
            macros: testMacros
        )
    }
}

// MARK: - @Tool

final class ToolMacroTests: XCTestCase {

    func testToolWithArgumentGeneratesFullMembers() {
        assertMacroExpansion(
            """
            @Tool("天気を取得", name: "get_weather")
            struct WeatherTool {
                @ToolArgument("都市名")
                var city: String

                func call() async throws -> String {
                    "晴れ"
                }
            }
            """,
            expandedSource: """
            struct WeatherTool {
                var city: String

                func call() async throws -> String {
                    "晴れ"
                }

                public let toolName: String = "get_weather"

                public let toolDescription: String = "天気を取得"
                public struct Arguments {
                    public var city: String = ""

                    public static var jsonSchema: JSONSchema {
                        JSONSchema(
                            type: .object,

                            properties: [
                                "city": JSONSchema(type: .string, description: "都市名")
                            ],
                            required: ["city"],
                            additionalProperties: false
                        )
                    }
                }

                public var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    self.city = ""
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.city = arguments.city
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.city = args.city
                    let result = try await copy.call()
                    return try result.asToolResult()
                }
            }

            extension Arguments: StructuredProtocol, Codable, Sendable {
            }

            extension WeatherTool: Tool, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    /// `@ToolArgument` に書いた制約がスキーマまで届くこと。
    ///
    /// 以前は `generateArgumentsType` が説明だけを `@StructuredField` に転記していたため、
    /// `.minimum(1)` などは解析されたあと捨てられ、モデルに見せるスキーマには入らなかった。
    /// ドキュメントは「スキーマに載る」と書いていたので、挙動とドキュメントが食い違っていた。
    func testToolArgumentConstraintsReachTheSchema() {
        assertMacroExpansion(
            """
            @Tool("検索する", name: "search")
            struct SearchTool {
                @ToolArgument("検索語", .minLength(1), .maxLength(100))
                var keyword: String

                @ToolArgument("最大件数", .minimum(1), .maximum(100))
                var limit: Int

                @ToolArgument("並び順", .enum(["relevance", "price_asc"]))
                var sortBy: String

                @ToolArgument("連絡先", .pattern("^[a-z]+$"), .format(.email))
                var contact: String

                func call() async throws -> String {
                    "ok"
                }
            }
            """,
            expandedSource: """
            struct SearchTool {
                var keyword: String
                var limit: Int
                var sortBy: String
                var contact: String

                func call() async throws -> String {
                    "ok"
                }

                public let toolName: String = "search"

                public let toolDescription: String = "検索する"
                public struct Arguments {
                    public var keyword: String = ""
                    public var limit: Int = 0
                    public var sortBy: String = ""
                    public var contact: String = ""

                    public static var jsonSchema: JSONSchema {
                        JSONSchema(
                            type: .object,

                            properties: [
                                "keyword": JSONSchema(type: .string, description: "検索語", minLength: 1, maxLength: 100),
                                "limit": JSONSchema(type: .integer, description: "最大件数", minimum: 1, maximum: 100),
                                "sort_by": JSONSchema(type: .string, description: "並び順", enum: ["relevance", "price_asc"]),
                                "contact": JSONSchema(type: .string, description: "連絡先", pattern: "^[a-z]+$", format: "email")
                            ],
                            required: ["keyword", "limit", "sort_by", "contact"],
                            additionalProperties: false
                        )
                    }
                }

                public var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    self.keyword = ""
                    self.limit = 0
                    self.sortBy = ""
                    self.contact = ""
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                    self.keyword = arguments.keyword
                    self.limit = arguments.limit
                    self.sortBy = arguments.sortBy
                    self.contact = arguments.contact
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.keyword = args.keyword
                    copy.limit = args.limit
                    copy.sortBy = args.sortBy
                    copy.contact = args.contact
                    let result = try await copy.call()
                    return try result.asToolResult()
                }
            }

            extension Arguments: StructuredProtocol, Codable, Sendable {
            }

            extension SearchTool: Tool, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    func testToolWithoutArgumentsUsesEmptyArguments() {
        assertMacroExpansion(
            """
            @Tool("現在時刻を取得")
            struct ClockTool {
                func call() async throws -> String {
                    "12:00"
                }
            }
            """,
            expandedSource: """
            struct ClockTool {
                func call() async throws -> String {
                    "12:00"
                }

                public let toolName: String = "clock_tool"

                public let toolDescription: String = "現在時刻を取得"

                public typealias Arguments = EmptyArguments

                public var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init(arguments: Arguments = EmptyArguments()) {
                    self.arguments = arguments
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let result = try await self.call()
                    return try result.asToolResult()
                }
            }

            extension ClockTool: Tool, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    func testToolWithInjectedPropertyGeneratesInjectionInitializers() {
        assertMacroExpansion(
            """
            @Tool("メモを検索")
            struct SearchTool {
                let store: NoteStore

                @ToolArgument("検索語")
                var query: String

                func call() async throws -> String {
                    query
                }
            }
            """,
            expandedSource: """
            struct SearchTool {
                let store: NoteStore
                var query: String

                func call() async throws -> String {
                    query
                }

                public let toolName: String = "search_tool"

                public let toolDescription: String = "メモを検索"
                public struct Arguments {
                    public var query: String = ""

                    public static var jsonSchema: JSONSchema {
                        JSONSchema(
                            type: .object,

                            properties: [
                                "query": JSONSchema(type: .string, description: "検索語")
                            ],
                            required: ["query"],
                            additionalProperties: false
                        )
                    }
                }

                public var inputSchema: JSONSchema {
                    Arguments.jsonSchema
                }

                public var arguments: Arguments

                public init(store: NoteStore) {
                    // ToolSet 登録時の初期化（注入プロパティを受け取る）
                    // LLM 引数は execute(with:) で設定される
                    self.store = store
                    self.query = ""
                    self.arguments = Arguments()
                }

                public init(store: NoteStore, arguments: Arguments) {
                    self.store = store
                    self.arguments = arguments
                    self.query = arguments.query
                }

                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let args = try decoder.decode(Arguments.self, from: argumentsData)
                    var copy = self
                    copy.arguments = args
                    copy.query = args.query
                    let result = try await copy.call()
                    return try result.asToolResult()
                }
            }

            extension Arguments: StructuredProtocol, Codable, Sendable {
            }

            extension SearchTool: Tool, Sendable {
            }
            """,
            macros: testMacros
        )
    }

    func testDiagnosticWhenAppliedToEnum() {
        assertMacroExpansion(
            """
            @Tool("不正")
            enum NotAStruct {
                case a
            }
            """,
            expandedSource: """
            enum NotAStruct {
                case a
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Tool can only be applied to structs",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }
}

// MARK: - @ToolArgument / @ToolExclude（マーカー peer マクロ）

final class ToolMarkerMacroTests: XCTestCase {

    func testToolArgumentExpandsToNothing() {
        assertMacroExpansion(
            """
            struct Plain {
                @ToolArgument("引数")
                var value: String
            }
            """,
            expandedSource: """
            struct Plain {
                var value: String
            }
            """,
            macros: testMacros
        )
    }

    func testToolExcludeExpandsToNothing() {
        assertMacroExpansion(
            """
            struct Plain {
                @ToolExclude
                var callback: (() -> Void)?
            }
            """,
            expandedSource: """
            struct Plain {
                var callback: (() -> Void)?
            }
            """,
            macros: testMacros
        )
    }
}

#else

// マクロホスト非対応環境（クロスコンパイル時など）では expansion テストをスキップする
final class LLMMacrosUnavailableTests: XCTestCase {
    func testMacrosNotAvailable() throws {
        throw XCTSkip("Macros are only supported when running tests for the host platform")
    }
}

#endif
