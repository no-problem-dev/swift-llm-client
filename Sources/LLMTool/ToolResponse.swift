import Foundation
import LLMClient

// MARK: - ToolResponse

/// ツール呼び出しへの応答
///
/// ツール実行結果を LLM に返すためのコンテナです。
/// 対応する `ToolCall` の ID で紐付けられます。
///
/// ## 使用例
///
/// ```swift
/// // ツール実行後に応答を作成
/// let call: ToolCall = ...
/// let result = try await executeTool(call)
///
/// let response = ToolResponse(
///     callId: call.id,
///     name: call.name,
///     output: result,
///     isError: false
/// )
///
/// // エラーの場合
/// let errorResponse = ToolResponse(
///     callId: call.id,
///     name: call.name,
///     output: "API rate limit exceeded",
///     isError: true
/// )
/// ```
public struct ToolResponse: Sendable, Equatable {
    /// 対応する ToolCall の ID
    public let callId: String

    /// ツール名
    public let name: String

    /// 実行結果コンテンツ
    public let content: ToolResultContent

    /// メディアコンテンツ（画像など）
    public let mediaContents: [ImageContent]

    // MARK: - Initializer

    public init(
        callId: String, name: String, content: ToolResultContent,
        mediaContents: [ImageContent] = []
    ) {
        self.callId = callId
        self.name = name
        self.content = content
        self.mediaContents = mediaContents
    }

    // MARK: - Convenience

    /// 出力文字列を取得
    public var output: String { content.contentValue }

    /// エラーかどうか
    public var isError: Bool { content.isError }
}
