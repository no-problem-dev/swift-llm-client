import Foundation

// MARK: - ToolChoice

/// ツール選択の動作モード
///
/// LLM がツールを使用するかどうか、どのように選択するかを制御する。
///
/// ## 使用例
///
/// ```swift
/// // 自動選択（デフォルト）
/// let result = try await client.generate(
///     input: "東京の天気は？",
///     model: .sonnet,
///     tools: tools,
///     toolChoice: .auto
/// )
///
/// // ツール使用を強制
/// let result = try await client.generate(
///     input: "天気を調べて",
///     model: .sonnet,
///     tools: tools,
///     toolChoice: .required
/// )
///
/// // 特定のツールを強制
/// let result = try await client.generate(
///     input: "天気を調べて",
///     model: .sonnet,
///     tools: tools,
///     toolChoice: .tool("get_weather")
/// )
/// ```
public enum ToolChoice: Sendable, Equatable {

    /// 自動選択（デフォルト）
    ///
    /// LLM がプロンプトに基づいてツールを使用するかを判断する。
    /// ツールが不要な場合はテキストのみで応答する可能性がある。
    case auto

    /// ツール使用を強制
    ///
    /// LLM は必ずいずれかのツールを使用する。
    /// どのツールを使用するかは LLM が選択する。
    case required

    /// ツール使用を禁止
    ///
    /// LLM はツールを使用せず、テキストのみで応答する。
    /// ツールが定義されていても無視される。
    case disabled

    /// 特定のツールを強制
    ///
    /// 指定された名前のツールを必ず使用する。
    ///
    /// - Parameter name: 使用するツールの名前
    case tool(String)
}

// MARK: - Parallel Tool Use

/// 並列ツール呼び出しの設定
///
/// LLM が単一リクエストで複数のツールを呼び出せるかを制御する。
public enum ParallelToolUse: Sendable, Equatable {

    /// 並列呼び出しを許可（デフォルト）
    ///
    /// LLM は必要に応じて複数のツールを同時に呼び出せる。
    case enabled

    /// 並列呼び出しを禁止
    ///
    /// LLM は一度に 1 つのツールのみ呼び出す。
    case disabled
}
