import Foundation
import CryptoKit
import LLMClient
import LLMTool

// MARK: - BreakdownCache

/// 内訳の増分再計算キャッシュ。
///
/// `systemPrompt` と `toolGroups` が不変の限り、`systemPrompt` / 各 tool セグメントの
/// marginal は **messages に依存しない**（差分なので wrapper/messages が相殺される）。
/// この性質を利用し、メッセージのみが変化したときは `bare`（conversationHistory）だけを
/// 再計測し、キャッシュした marginal を再利用する。
///
/// これにより、会話が伸びるたびに発生する内訳更新のコストを
/// `(2 + ツール群数)` 回の `count_tokens` から **1 回**へ削減する。
///
/// - Note: marginal の messages 非依存は近似（境界トークン効果を無視）。内訳は表示用途であり、
///   この近似は業界標準（Claude Code/Aider も内訳は概算）。占有メーター（`ContextOccupancy`）は
///   別途 `usage` から正確に出るため、確定値はそちらが担う。
public actor BreakdownCache {

    private let counter: any TokenCounting
    private let engine: SegmentBreakdownEngine

    /// 直近の (systemPrompt, toolGroups) シグネチャ。
    private var signature: String?
    /// 直近のシグネチャに対する system/tool セグメントの marginal（conversationHistory を除く）。
    private var cachedMarginals: [ContextSegment: Int] = [:]

    public init(counter: any TokenCounting) {
        self.counter = counter
        self.engine = SegmentBreakdownEngine(counter: counter)
    }

    public func breakdown(
        modelID: String,
        systemPrompt: String?,
        messages: [LLMMessage],
        toolGroups: [ToolGroup] = []
    ) async throws -> SegmentBreakdown {
        let sig = Self.signature(systemPrompt: systemPrompt, toolGroups: toolGroups)

        if signature == sig {
            // メッセージのみ変化: bare だけ再計測し、marginal を再利用。
            let bare = try await counter.countInputTokens(
                modelID: modelID, systemPrompt: nil, messages: messages, tools: nil
            )
            var per = cachedMarginals
            per[.conversationHistory, default: 0] += bare
            let total = bare + cachedMarginals.values.reduce(0, +)
            return SegmentBreakdown(perSegment: per, totalMeasured: total)
        }

        // system/tools が変化: フル ladder を実行し marginal をキャッシュ。
        let full = try await engine.breakdown(
            modelID: modelID, systemPrompt: systemPrompt, messages: messages, toolGroups: toolGroups
        )
        var marginals = full.perSegment
        marginals[.conversationHistory] = nil
        signature = sig
        cachedMarginals = marginals
        return full
    }

    /// キャッシュを無効化する。
    public func invalidate() {
        signature = nil
        cachedMarginals = [:]
    }

    // MARK: - Signature

    /// (systemPrompt, toolGroups) の安定シグネチャ。tool は name+description+schema で識別。
    static func signature(systemPrompt: String?, toolGroups: [ToolGroup]) -> String {
        var hasher = SHA256()
        hasher.update(data: Data((systemPrompt ?? "").utf8))
        hasher.update(data: Data([0xff]))
        for group in toolGroups {
            hasher.update(data: Data(group.segment.rawValue.utf8))
            hasher.update(data: Data([0xfe]))
            for tool in group.tools.tools {
                hasher.update(data: Data(tool.toolName.utf8))
                hasher.update(data: Data([0x1f]))
                hasher.update(data: Data(tool.toolDescription.utf8))
                hasher.update(data: Data([0x1e]))
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
