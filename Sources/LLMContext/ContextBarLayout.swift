import Foundation
import LLMClient

// MARK: - ContextBarSegment

/// スタックバー 1 区画。`fraction` はウィンドウ（不明時は used）に対する比率 0...1。
public struct ContextBarSegment: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case systemPrompt, toolDefinitions, mcpToolDefinitions, memoryFiles
        case latestToolResults, conversationHistory
        case cached, fresh   // 内訳が無い時の占有モード
        case free
    }

    public let kind: Kind
    public let tokens: Int
    /// ウィンドウ（不明時は used 総量）に対する比率 0...1。
    public let fraction: Double

    public init(kind: Kind, tokens: Int, fraction: Double) {
        self.kind = kind
        self.tokens = tokens
        self.fraction = fraction
    }
}

// MARK: - ContextBarLayout

/// `ContextReport` を表示用スタックバーに変換する純ロジック（SwiftUI 非依存）。
///
/// - 内訳（`breakdown`）があればカテゴリ別区画 + 空き。
/// - 無ければ占有（`occupancy`）から fresh / cached / 空きの区画。
/// - `windowSize` が `nil`（モデル未定義）なら used 総量で正規化し、空き区画は出さない
///   （占有率を捏造しない = silent fallback 排除）。
public struct ContextBarLayout: Sendable, Hashable {

    public let segments: [ContextBarSegment]
    public let windowSize: Int?
    public let usedTokens: Int

    public init(report: ContextReport) {
        let occ = report.occupancy
        let window = occ.windowSize
        self.windowSize = window
        self.usedTokens = occ.used

        // 比率の分母: ウィンドウ既知ならウィンドウ、未知なら used（最低 1）。
        let denom = Double(window ?? max(occ.used, 1))
        func frac(_ tokens: Int) -> Double { denom > 0 ? Double(tokens) / denom : 0 }

        var result: [ContextBarSegment] = []

        if let breakdown = report.breakdown {
            // 内訳モード: 安定した表示順で区画化。
            let order: [(ContextSegment, ContextBarSegment.Kind)] = [
                (.systemPrompt, .systemPrompt),
                (.toolDefinitions, .toolDefinitions),
                (.mcpToolDefinitions, .mcpToolDefinitions),
                (.memoryFiles, .memoryFiles),
                (.latestToolResults, .latestToolResults),
                (.conversationHistory, .conversationHistory),
            ]
            for (segment, kind) in order {
                let tokens = breakdown.tokens(for: segment)
                if tokens > 0 {
                    result.append(ContextBarSegment(kind: kind, tokens: tokens, fraction: frac(tokens)))
                }
            }
        } else {
            // 占有モード: fresh / cached（cached は占有するが安価なので別区画）。
            let cached = occ.cacheReadTokens + occ.cacheCreationTokens
            let fresh = max(0, occ.used - cached)
            if fresh > 0 {
                result.append(ContextBarSegment(kind: .fresh, tokens: fresh, fraction: frac(fresh)))
            }
            if cached > 0 {
                result.append(ContextBarSegment(kind: .cached, tokens: cached, fraction: frac(cached)))
            }
        }

        // 空き区画（ウィンドウ既知時のみ）。
        if let free = occ.free, free > 0 {
            result.append(ContextBarSegment(kind: .free, tokens: free, fraction: frac(free)))
        }

        self.segments = result
    }
}
