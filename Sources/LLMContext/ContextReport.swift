import Foundation
import LLMClient

// MARK: - ContextReport

/// 1 エージェント（host または各サブエージェント A2）のコンテキストウィンドウ状況。
///
/// - `occupancy`: `usage` から正確・無料・即時に出るライブ占有（常時表示）。
/// - `breakdown`: `count_tokens` 差分減算によるカテゴリ別内訳（オンデマンド・キャッシュ）。
public struct ContextReport: Sendable {

    /// ライブ占有メーター（(i) 正確・即時）。
    public let occupancy: ContextOccupancy

    /// カテゴリ別内訳（(ii) オンデマンド）。未取得なら `nil`。
    public var breakdown: SegmentBreakdown?

    public init(occupancy: ContextOccupancy, breakdown: SegmentBreakdown? = nil) {
        self.occupancy = occupancy
        self.breakdown = breakdown
    }
}
