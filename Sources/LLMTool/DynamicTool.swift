import Foundation
import LLMClient

// MARK: - DynamicTool

/// ランタイムで定義可能なツール
///
/// `@Tool` マクロを使わずに、プログラマティックにツールを定義できます。
/// `SchemaFieldBuilder` DSL を使用してパラメータを宣言的に構築し、
/// `ToolArguments` 経由で型安全に引数にアクセスできます。
///
/// ## 使用例
///
/// ```swift
/// // Builder DSL でパラメータ定義
/// let weatherTool = DynamicTool("get_weather", description: "天気を取得") {
///     JSONSchema.string(description: "都市名").named("city")
///     JSONSchema.enum(["celsius", "fahrenheit"], description: "単位")
///         .named("unit").optional()
/// } handler: { args in
///     let city = args.string("city") ?? "unknown"
///     return .text("Weather in \(city): 25°C")
/// }
///
/// // パラメータなし
/// let timeTool = DynamicTool("get_time", description: "現在時刻を取得") {
///     .text(ISO8601DateFormatter().string(from: Date()))
/// }
///
/// // ToolSet で組み合わせ
/// let tools = ToolSet {
///     weatherTool
///     timeTool
/// }
/// ```
public struct DynamicTool: Tool, Sendable {
    public let toolName: String
    public let toolDescription: String
    public let inputSchema: JSONSchema
    public let annotations: ToolAnnotations

    private let executeHandler: @Sendable (Data) async throws -> ToolResult

    // MARK: - Init 1: SchemaFieldBuilder DSL + ToolArguments

    /// SchemaFieldBuilder DSL と ToolArguments ハンドラーで初期化
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - description: ツールの説明
    ///   - annotations: ツールアノテーション
    ///   - parameters: パラメータ定義クロージャ
    ///   - handler: ToolArguments を受け取る実行ハンドラー
    public init(
        _ name: String,
        description: String,
        annotations: ToolAnnotations = ToolAnnotations(),
        @SchemaFieldBuilder parameters: () -> [NamedSchema],
        handler: @escaping @Sendable (ToolArguments) async throws -> ToolResult
    ) {
        let fields = parameters()
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = JSONSchema.object(fields: fields, additionalProperties: false)
        self.annotations = annotations
        self.executeHandler = { data in
            let args = try ToolArguments(from: data)
            return try await handler(args)
        }
    }

    // MARK: - Init 2: SchemaFieldBuilder DSL + raw Data

    /// SchemaFieldBuilder DSL と生データハンドラーで初期化
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - description: ツールの説明
    ///   - annotations: ツールアノテーション
    ///   - parameters: パラメータ定義クロージャ
    ///   - rawHandler: 生の Data を受け取る実行ハンドラー
    public init(
        _ name: String,
        description: String,
        annotations: ToolAnnotations = ToolAnnotations(),
        @SchemaFieldBuilder parameters: () -> [NamedSchema],
        rawHandler: @escaping @Sendable (Data) async throws -> ToolResult
    ) {
        let fields = parameters()
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = JSONSchema.object(fields: fields, additionalProperties: false)
        self.annotations = annotations
        self.executeHandler = rawHandler
    }

    // MARK: - Init 3: Direct schema + ToolArguments

    /// 直接スキーマ指定と ToolArguments ハンドラーで初期化
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - description: ツールの説明
    ///   - inputSchema: 入力スキーマ
    ///   - annotations: ツールアノテーション
    ///   - handler: ToolArguments を受け取る実行ハンドラー
    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        annotations: ToolAnnotations = ToolAnnotations(),
        handler: @escaping @Sendable (ToolArguments) async throws -> ToolResult
    ) {
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = inputSchema
        self.annotations = annotations
        self.executeHandler = { data in
            let args = try ToolArguments(from: data)
            return try await handler(args)
        }
    }

    // MARK: - Init 4: No parameters

    /// パラメータなしで初期化
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - description: ツールの説明
    ///   - annotations: ツールアノテーション
    ///   - handler: 引数なしの実行ハンドラー
    public init(
        _ name: String,
        description: String,
        annotations: ToolAnnotations = ToolAnnotations(),
        handler: @escaping @Sendable () async throws -> ToolResult
    ) {
        self.toolName = name
        self.toolDescription = description
        self.inputSchema = JSONSchema.object(properties: [:], additionalProperties: false)
        self.annotations = annotations
        self.executeHandler = { _ in
            try await handler()
        }
    }

    // MARK: - Tool Protocol

    public func execute(with argumentsData: Data) async throws -> ToolResult {
        try await executeHandler(argumentsData)
    }
}
