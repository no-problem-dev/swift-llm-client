import LLMClient

/// ツール引数の型エイリアス
///
/// `DynamicTool` のハンドラーで引数にアクセスする際に使用します。
/// `DynamicJSON` の型安全なアクセサメソッドを通じて引数値を取得できます。
///
/// ## 使用例
///
/// ```swift
/// let tool = DynamicTool("get_weather", description: "天気を取得") {
///     JSONSchema.string(description: "都市名").named("city")
/// } handler: { (args: ToolArguments) in
///     let city = args.string("city") ?? "unknown"
///     return .text("Weather in \(city): 25°C")
/// }
/// ```
public typealias ToolArguments = DynamicJSON
