import StructuredDataCore

/// ツール引数の型エイリアス。
///
/// `DynamicTool` のハンドラーで引数にアクセスする際に使用します。中立中間表現
/// ``StructuredValue`` の型安全アクセサ(`string(_:)` / `int(_:)` / dynamicMemberLookup /
/// 型付き subscript 等)で引数値を取得できます。
///
/// ```swift
/// let tool = DynamicTool("get_weather", description: "天気を取得") {
///     JSONSchema.string(description: "都市名").named("city")
/// } handler: { (args: ToolArguments) in
///     let city = args.string("city") ?? "unknown"
///     return .text("Weather in \(city): 25°C")
/// }
/// ```
public typealias ToolArguments = StructuredValue
