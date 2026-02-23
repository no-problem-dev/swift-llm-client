import Foundation
import LLMClient

// MARK: - ToolSet

/// ツールの集合
///
/// Result Builder を使用して宣言的にツールを構築できます。
/// SwiftUI の View と同様のパターンで、条件分岐やループもサポートしています。
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     GetWeatherTool(apiKey: weatherApiKey)
///     SearchTool()
///
///     if needsCalculator {
///         CalculatorTool()
///     }
///
///     for tool in dynamicTools {
///         tool
///     }
/// }
///
/// let result = try await client.generate(
///     input: "東京の天気は？",
///     model: .sonnet,
///     tools: tools
/// )
/// ```
///
/// ## ツールの結合
///
/// ```swift
/// let baseTools = ToolSet {
///     GetWeatherTool()
///     SearchTool()
/// }
///
/// let extendedTools = baseTools.appending(CalculatorTool())
/// ```
public struct ToolSet: Sendable {

    // MARK: - Properties

    /// 内部のツール配列
    public let tools: [any Tool]

    // MARK: - Initializers

    /// Result Builder でツールセットを構築
    ///
    /// - Parameter builder: ツールを構築するクロージャ
    ///
    /// ```swift
    /// let tools = ToolSet {
    ///     GetWeatherTool()
    ///     SearchTool()
    /// }
    /// ```
    public init(@ToolSetBuilder _ builder: () -> [any Tool]) {
        self.tools = builder()
    }

    /// 配列から直接初期化
    public init(tools: [any Tool]) {
        self.tools = tools
    }

    /// 空の ToolSet を作成
    public init() {
        self.tools = []
    }

    // MARK: - Properties

    /// ツールセットが空かどうか
    public var isEmpty: Bool {
        tools.isEmpty
    }

    /// ツールの数
    public var count: Int {
        tools.count
    }

    /// ツール名のリスト
    public var toolNames: [String] {
        tools.map { $0.name }
    }

    // MARK: - Lookup

    /// 名前でツールを検索
    ///
    /// - Parameter name: ツール名
    /// - Returns: 見つかったツール
    public func tool(named name: String) -> (any Tool)? {
        tools.first { $0.name == name }
    }

    /// ツール定義のリストを取得
    public var definitions: [ToolDefinition] {
        tools.map { $0.definition }
    }

    /// 名前でツールを実行
    ///
    /// - Parameters:
    ///   - name: ツール名
    ///   - argumentsData: 引数の JSON データ
    /// - Returns: ツールの実行結果
    /// - Throws: ツールが見つからない場合、または実行エラー
    public func execute(toolNamed name: String, with argumentsData: Data) async throws -> ToolResult {
        guard let tool = tool(named: name) else {
            throw ToolExecutionError.toolNotFound(name)
        }
        return try await tool.execute(with: argumentsData)
    }
}

// MARK: - ToolExecutionError

/// ツール実行時のエラー
public enum ToolExecutionError: Error, LocalizedError {
    /// ツールが見つからない
    case toolNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        }
    }
}

// MARK: - ToolSet Combination

extension ToolSet {
    /// 2つの ToolSet を結合
    ///
    /// - Parameters:
    ///   - lhs: 最初の ToolSet
    ///   - rhs: 追加する ToolSet
    /// - Returns: 結合された ToolSet
    public static func + (lhs: ToolSet, rhs: ToolSet) -> ToolSet {
        ToolSet(tools: lhs.tools + rhs.tools)
    }

    /// ToolSet にツールを追加
    ///
    /// - Parameters:
    ///   - lhs: ToolSet
    ///   - rhs: 追加するツール
    /// - Returns: ツールが追加された ToolSet
    public static func + (lhs: ToolSet, rhs: some Tool) -> ToolSet {
        ToolSet(tools: lhs.tools + [rhs])
    }

    /// 別の ToolSet を追加した新しい ToolSet を返す
    ///
    /// - Parameter other: 追加する ToolSet
    /// - Returns: 結合された ToolSet
    public func appending(_ other: ToolSet) -> ToolSet {
        self + other
    }

    /// ツールを追加した新しい ToolSet を返す
    ///
    /// - Parameter tool: 追加するツール
    /// - Returns: ツールが追加された ToolSet
    public func appending(_ tool: some Tool) -> ToolSet {
        self + tool
    }
}

// MARK: - CustomStringConvertible

extension ToolSet: CustomStringConvertible {
    public var description: String {
        let names = toolNames.joined(separator: ", ")
        return "ToolSet(\(count) tools: \(names))"
    }
}

// MARK: - Provider Format Conversion

extension ToolSet {
    /// 指定されたアダプターを使用して、ツール定義をプロバイダー固有の形式に変換
    ///
    /// - Parameters:
    ///   - adapter: スキーマアダプター
    ///   - formatBuilder: 各ツールをプロバイダー形式に変換するクロージャ
    /// - Returns: 変換されたツール定義の配列
    public func toProviderFormat(
        adapter: some ProviderSchemaAdapter,
        formatBuilder: (any Tool, _ adaptedSchema: [String: Any]?) -> [String: Any]
    ) -> [[String: Any]] {
        tools.map { tool in
            let adaptedSchemaDict: [String: Any]?
            if let schemaData = try? adapter.adapt(tool.inputSchema).toJSONData(),
               let schemaDict = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
                adaptedSchemaDict = schemaDict
            } else {
                adaptedSchemaDict = nil
            }
            return formatBuilder(tool, adaptedSchemaDict)
        }
    }
}
