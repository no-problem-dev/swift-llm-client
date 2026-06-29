import Foundation

// MARK: - SystemPromptMetadata

/// システムプロンプトの表示用メタデータ
///
/// UI でのプロンプトカタログ表示、プリセット一覧、
/// 詳細画面で使用されるメタ情報を保持する。
///
/// ## 使用例
///
/// ```swift
/// let metadata = SystemPromptMetadata(
///     id: "researcher",
///     name: "Researcher",
///     description: "情報収集、分析、統合タスクに最適化",
///     iconName: "magnifyingglass",
///     tags: ["research", "analysis"]
/// )
/// ```
public struct SystemPromptMetadata: Sendable, Equatable, Codable, Identifiable, Hashable {

    /// 一意な識別子
    public let id: String

    /// 表示名
    public let name: String

    /// 説明文
    public let description: String

    /// SF Symbols アイコン名
    public let iconName: String

    /// タグ（カテゴリ分類用）
    public let tags: [String]

    /// SystemPromptMetadata を初期化
    ///
    /// - Parameters:
    ///   - id: 一意な識別子
    ///   - name: 表示名
    ///   - description: 説明文
    ///   - iconName: SF Symbols アイコン名
    ///   - tags: タグ（カテゴリ分類用）
    public init(
        id: String,
        name: String,
        description: String,
        iconName: String,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.tags = tags
    }
}
