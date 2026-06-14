import Foundation
import LLMClient
import LLMTool

// MARK: - SegmentBreakdownEngine

/// `count_tokens` の **差分減算**でカテゴリ別内訳を算出する純ロジック。
///
/// ## なぜ差分減算か（最重要）
/// `count_tokens` は呼び出しごとに隠れた per-request system wrapper（数百トークン）を含む。
/// 各セグメントを**単独で数えて合算**すると、この wrapper を N 重に計上してしまう
/// （Claude Code `/context` が MCP ツールを約 3 倍過大計上していた実バグ）。
///
/// 本エンジンは全ての計測段（rung）を**同一の実 messages** に対して行い、system/tools を
/// トグルした superset の差分を取る。これにより wrapper は隣接段で相殺され、
/// `systemPrompt` / 各 tool セグメントは wrapper を含まない clean marginal になる。
///
/// ```
/// bare    = count(system: nil, tools: nil,        messages: msgs)  // = wrapper + messages
/// sysOnly = count(system: sys, tools: nil,        messages: msgs)  // = wrapper + sys + messages
/// rung_k  = count(system: sys, tools: tools[0..k], messages: msgs)
///
/// systemPrompt        = sysOnly - bare            // wrapper, messages 相殺 → 純 system
/// toolGroup_k         = rung_k  - rung_{k-1}      // 純 tool 群 k
/// conversationHistory = bare                       // 不可避 wrapper を内包する基底
/// totalMeasured       = rung_last                  // = 全部入り
/// ```
///
/// 構成上 `Σ perSegment == totalMeasured` が厳密に成立する。
public struct SegmentBreakdownEngine: Sendable {

    public let counter: any TokenCounting

    public init(counter: any TokenCounting) {
        self.counter = counter
    }

    /// 差分減算でカテゴリ別内訳を算出する。
    ///
    /// - Parameters:
    ///   - model: 対象モデル（トークナイザ選択に使用）。
    ///   - systemPrompt: システムプロンプト（nil/空ならその段はスキップ）。
    ///   - messages: 会話メッセージ（全 rung で共通の実データ）。
    ///   - toolGroups: セグメント付きツール群。先頭から累積的に差分計測される。
    public func breakdown(
        modelID: String,
        systemPrompt: String?,
        messages: [LLMMessage],
        toolGroups: [ToolGroup] = []
    ) async throws -> SegmentBreakdown {
        // rung 0: bare（= wrapper + messages）。不可避 overhead を conversationHistory に内包。
        let bare = try await counter.countInputTokens(
            modelID: modelID, systemPrompt: nil, messages: messages, tools: nil
        )
        var per: [ContextSegment: Int] = [.conversationHistory: bare]
        var prev = bare

        // rung 1: + system（marginal, wrapper/messages 相殺）。
        let hasSystem = (systemPrompt?.isEmpty == false)
        if hasSystem {
            let sysOnly = try await counter.countInputTokens(
                modelID: modelID, systemPrompt: systemPrompt, messages: messages, tools: nil
            )
            per[.systemPrompt, default: 0] += (sysOnly - prev)
            prev = sysOnly
        }

        // rung 2..n: ツール群を累積追加（各 marginal）。
        var accumulated: [any Tool] = []
        for group in toolGroups where !group.tools.isEmpty {
            accumulated += group.tools.tools
            let count = try await counter.countInputTokens(
                modelID: modelID,
                systemPrompt: hasSystem ? systemPrompt : nil,
                messages: messages,
                tools: ToolSet(tools: accumulated)
            )
            per[group.segment, default: 0] += (count - prev)
            prev = count
        }

        return SegmentBreakdown(perSegment: per, totalMeasured: prev)
    }
}
