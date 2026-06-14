import Foundation
import LLMClient
import LLMTool

// MARK: - ContextSegment

/// コンテキストウィンドウを占有する内容カテゴリ。プロバイダ非依存。
public enum ContextSegment: String, Sendable, Hashable, CaseIterable, Codable {
    /// システムプロンプト
    case systemPrompt
    /// 組み込みツール定義
    case toolDefinitions
    /// MCP ツール定義
    case mcpToolDefinitions
    /// メモリ / プロジェクトファイル
    case memoryFiles
    /// 会話履歴（不可避な per-request overhead を内包する基底）
    case conversationHistory
    /// 直近ターンのツール結果
    case latestToolResults
}

// MARK: - ToolGroup

/// 内訳算出時に「どの ToolSet をどのセグメントへ計上するか」を表すグループ。
///
/// 例: 組み込みツールを `.toolDefinitions`、MCP ツールを `.mcpToolDefinitions` へ。
/// `SegmentBreakdownEngine` はこの順序で累積的にツールを差分計測する。
public struct ToolGroup: Sendable {
    public let segment: ContextSegment
    public let tools: ToolSet

    public init(segment: ContextSegment, tools: ToolSet) {
        self.segment = segment
        self.tools = tools
    }
}

// MARK: - SegmentBreakdown

/// カテゴリ別トークン内訳。
///
/// **不変条件**: `perSegment` の総和は `totalMeasured`（= 全部入りの count）に厳密一致する
/// （差分減算による構成のため）。これは取りこぼし／二重計上が無いことの検算でもある。
public struct SegmentBreakdown: Sendable, Hashable {
    public let perSegment: [ContextSegment: Int]
    /// 全構成要素を含めた実測トークン（差分整合の基準）。
    public let totalMeasured: Int

    public init(perSegment: [ContextSegment: Int], totalMeasured: Int) {
        self.perSegment = perSegment
        self.totalMeasured = totalMeasured
    }

    /// 指定セグメントのトークン（未計上は 0）。
    public func tokens(for segment: ContextSegment) -> Int {
        perSegment[segment] ?? 0
    }

    /// `perSegment` の総和が `totalMeasured` に一致するか（整合検算）。
    public var isConsistent: Bool {
        perSegment.values.reduce(0, +) == totalMeasured
    }
}
