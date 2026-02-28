import Foundation

// MARK: - ToolAnnotations

/// ツールの動作特性を示すアノテーション
///
/// MCP仕様のTool Annotationsに準拠した構造体です。
/// クライアントがツールの特性を理解するためのヒントを提供します。
///
/// - Note: これらはすべて「ヒント」であり、
///         信頼できないサーバーからの値は検証せずに信用すべきではありません。
///
/// ## 使用例
///
/// ```swift
/// let annotations = ToolAnnotations(
///     title: "ファイル読み取り",
///     readOnlyHint: true
/// )
/// ```
public struct ToolAnnotations: Sendable, Equatable {
    /// 人間可読なツールタイトル
    public var title: String?

    /// trueの場合、ツールは環境を変更しない
    ///
    /// デフォルト: false（未指定時）
    public var readOnlyHint: Bool?

    /// trueの場合、ツールは破壊的な更新を行う可能性がある
    ///
    /// `readOnlyHint == false` の場合のみ意味を持ちます。
    /// デフォルト: true（未指定時）
    public var destructiveHint: Bool?

    /// trueの場合、同じ引数での繰り返し呼び出しは追加の効果を持たない
    ///
    /// `readOnlyHint == false` の場合のみ意味を持ちます。
    /// デフォルト: false（未指定時）
    public var idempotentHint: Bool?

    /// trueの場合、ツールは外部エンティティと対話する可能性がある
    ///
    /// 例: Web検索ツールはopen world、メモリツールはclosed world
    /// デフォルト: true（未指定時）
    public var openWorldHint: Bool?

    public init(
        title: String? = nil,
        readOnlyHint: Bool? = nil,
        destructiveHint: Bool? = nil,
        idempotentHint: Bool? = nil,
        openWorldHint: Bool? = nil
    ) {
        self.title = title
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
        self.idempotentHint = idempotentHint
        self.openWorldHint = openWorldHint
    }

    /// 読み取り専用ツール用のプリセット
    public static let readOnly = ToolAnnotations(readOnlyHint: true)

    /// 破壊的な書き込みツール用のプリセット
    public static let destructive = ToolAnnotations(
        readOnlyHint: false,
        destructiveHint: true
    )

    /// 冪等な書き込みツール用のプリセット
    public static let idempotentWrite = ToolAnnotations(
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: true
    )

    /// クローズドワールドツール用のプリセット（メモリ等）
    public static let closedWorld = ToolAnnotations(openWorldHint: false)
}
