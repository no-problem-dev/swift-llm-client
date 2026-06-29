import Foundation

// MARK: - SchemaFieldBuilder

/// `[NamedSchema]` を宣言的に構築するための Result Builder
///
/// `JSONSchema` とその拡張メソッド `.named()` を組み合わせて、
/// スキーマフィールドの定義をパズルのように組み立てられる。
/// `DynamicStructured` と `DynamicTool` の両方で使用する。
///
/// ## 使用例
///
/// ```swift
/// // DynamicStructured で使用
/// let userInfo = DynamicStructured("UserInfo") {
///     JSONSchema.string(description: "ユーザー名")
///         .named("name")
///
///     JSONSchema.integer(description: "年齢", minimum: 0)
///         .named("age")
///         .optional()
/// }
///
/// // DynamicTool で使用
/// let tool = DynamicTool("get_weather", description: "天気を取得") {
///     JSONSchema.string(description: "都市名").named("city")
///     JSONSchema.enum(["celsius", "fahrenheit"], description: "単位")
///         .named("unit").optional()
/// } handler: { args in
///     .text("Weather in \(args.string("city") ?? "unknown")")
/// }
/// ```
@resultBuilder
public struct SchemaFieldBuilder {
    /// 複数のフィールドを結合
    public static func buildBlock(_ components: NamedSchemaConvertible...) -> [NamedSchema] {
        components.map { $0.asNamedSchema() }
    }

    /// 複数の配列を結合
    public static func buildBlock(_ components: [NamedSchema]...) -> [NamedSchema] {
        components.flatMap { $0 }
    }

    /// 単一の式を配列に変換
    public static func buildExpression(_ expression: NamedSchemaConvertible) -> [NamedSchema] {
        [expression.asNamedSchema()]
    }

    /// オプショナルな要素を処理
    public static func buildOptional(_ component: [NamedSchema]?) -> [NamedSchema] {
        component ?? []
    }

    /// if-else の最初の分岐
    public static func buildEither(first component: [NamedSchema]) -> [NamedSchema] {
        component
    }

    /// if-else の2番目の分岐
    public static func buildEither(second component: [NamedSchema]) -> [NamedSchema] {
        component
    }

    /// for ループからの配列を結合
    public static func buildArray(_ components: [[NamedSchema]]) -> [NamedSchema] {
        components.flatMap { $0 }
    }

    /// 最終結果を返す
    public static func buildFinalResult(_ component: [NamedSchema]) -> [NamedSchema] {
        component
    }
}
