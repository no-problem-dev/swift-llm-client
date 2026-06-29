import Foundation
import LLMClient

// MARK: - Tool Protocol

/// LLM が呼び出し可能なツールを定義するプロトコル
///
/// このプロトコルに準拠した型は LLM からの関数呼び出しを処理できる。
/// 通常は `@Tool` マクロで自動的に準拠される。
///
/// ## 使用例（マクロ使用）
///
/// ```swift
/// @Tool("指定された都市の天気を取得します")
/// struct GetWeather {
///     // 設定プロパティ（オプショナル）
///     var apiKey: String?
///
///     @ToolArgument("都市名")
///     var location: String
///
///     @ToolArgument("温度の単位", .enum(["celsius", "fahrenheit"]))
///     var unit: String?
///
///     func call() async throws -> String {
///         // 天気 API を呼び出す
///         return "東京: 晴れ、25°C"
///     }
/// }
/// ```
///
/// ## ToolSet での使用
///
/// ```swift
/// let tools = ToolSet {
///     GetWeather(apiKey: "xxx")
///     SearchWeb()
///     Calculator()
/// }
/// ```
public protocol Tool: Sendable {
    /// ツールの識別子
    ///
    /// API で使用される名前。
    /// `^[a-zA-Z0-9_-]{1,64}$` のパターンに従う必要がある。
    var toolName: String { get }

    /// ツールの説明
    ///
    /// LLM がツールを選択する際に参照する説明文。
    /// 詳細に記述することで適切なタイミングで呼び出されやすくなる。
    var toolDescription: String { get }

    /// 引数の JSON Schema
    ///
    /// ツールの入力パラメータを定義する JSON Schema。
    var inputSchema: JSONSchema { get }

    /// このツールがアタッチされたとき system prompt に同伴させる指示（ADK `process_llm_request` 相当）
    ///
    /// スキーマ・手本などツールの前提知識はツール自身が所有し、ループランタイムが
    /// system prompt の末尾へ追記する。`nil` = 追記なし（既定）。
    var systemInstruction: String? { get }

    /// ツールを実行
    ///
    /// LLM から呼び出された際に実行される。
    /// インスタンスメソッドとして実装することで設定プロパティにアクセスできる。
    ///
    /// - Parameter argumentsData: 引数の JSON データ
    /// - Returns: ツールの実行結果
    /// - Throws: 引数のデコードエラーまたは実行エラー
    func execute(with argumentsData: Data) async throws -> ToolResult
}

// MARK: - TurnEndingTool

/// 成功結果がエージェントターンを終了させるツール（ADK の `skip_summarization` 相当の契約）
///
/// ループランタイムは、このプロトコルに準拠したツールの非エラー結果を受け取ったら、
/// 結果をモデルへ返す追加推論を行わずにターンを終える。エラー結果は通常どおりモデルへ
/// 返り、ループは継続する（モデルが自己修正・謝罪できる）。
///
/// 宣言（ツール層）と実施（ループランタイム層）を分離するためのマーカープロトコル。
public protocol TurnEndingTool: Tool {}

// MARK: - Tool Convenience Properties

extension Tool {
    /// 既定では system prompt への追記なし
    public var systemInstruction: String? { nil }

    /// ツール名へのエイリアス
    public var name: String { toolName }

    /// ツールの説明へのエイリアス
    public var description: String { toolDescription }
}

// MARK: - EmptyArguments

/// 引数を持たないツール用の空の引数型
///
/// ツールがパラメータを必要としない場合に使用する。
///
/// ```swift
/// @Tool("現在時刻を取得します")
/// struct GetCurrentTime {
///     // 引数なし - EmptyArguments が自動的に使用される
///
///     func call() async throws -> String {
///         return ISO8601DateFormatter().string(from: Date())
///     }
/// }
/// ```
@Structured
public struct EmptyArguments {
    public init() {}
}
