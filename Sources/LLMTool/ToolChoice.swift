import Foundation

// MARK: - ToolChoice

/// ツール選択の動作モード
///
/// LLM がツールを使用するかどうか、どのように選択するかを制御します。
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
    /// LLM がプロンプトに基づいてツールを使用するかどうかを判断します。
    /// ツールが不要な場合は、テキストのみで応答する可能性があります。
    case auto

    /// ツール使用を強制
    ///
    /// LLM は必ずいずれかのツールを使用します。
    /// どのツールを使用するかは LLM が選択します。
    case required

    /// ツール使用を禁止
    ///
    /// LLM はツールを使用せず、テキストのみで応答します。
    /// ツールが定義されていても無視されます。
    case disabled

    /// 特定のツールを強制
    ///
    /// 指定された名前のツールを必ず使用します。
    ///
    /// - Parameter name: 使用するツールの名前
    case tool(String)
}

// MARK: - Parallel Tool Use

/// 並列ツール呼び出しの設定
///
/// LLM が単一のリクエストで複数のツールを呼び出せるかどうかを制御します。
public enum ParallelToolUse: Sendable, Equatable {

    /// 並列呼び出しを許可（デフォルト）
    ///
    /// LLM は必要に応じて複数のツールを同時に呼び出すことができます。
    case enabled

    /// 並列呼び出しを禁止
    ///
    /// LLM は一度に1つのツールのみ呼び出します。
    case disabled
}
