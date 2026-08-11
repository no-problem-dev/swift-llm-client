import Foundation
import LLMClient
import LLMTool

// MARK: - SegmentBreakdownEngine

/// Attributes a context window to categories by differencing token counts.
///
/// ## Why differencing, and not counting each part
///
/// Every token count carries the provider's own hidden per-request wrapper, a few hundred tokens
/// that belong to no segment. Counting each segment on its own and adding the results charges that
/// wrapper once per segment: the same mistake that had Claude Code's context view reporting MCP
/// tools at roughly three times their real size.
///
/// So every measurement here is taken against the same real messages, toggling only the system
/// prompt and the tools. Adjacent counts differ by exactly one segment, the wrapper cancels
/// between them, and what is left for the system prompt and each tool group is a clean marginal
/// cost.
///
/// ```
/// bare    = count(system: nil, tools: nil,        messages: msgs)  // wrapper + messages (the baseline)
/// sysOnly = count(system: sys, tools: nil,        messages: msgs)  // wrapper + system + messages
/// rung_k  = count(system: sys, tools: tools[0..k], messages: msgs)
///
/// systemPrompt        = sysOnly - bare            // wrapper and messages cancel: the system prompt alone
/// toolGroup_k         = rung_k  - rung_{k-1}      // tool group k alone
/// conversationHistory = bare                       // the baseline, wrapper included
/// totalMeasured       = rung_last                  // everything together
/// ```
///
/// By construction the segments sum exactly to the total.
public struct SegmentBreakdownEngine: Sendable {

    public let counter: any TokenCounting

    public init(counter: any TokenCounting) {
        self.counter = counter
    }

    /// Measures the breakdown by differencing token counts.
    ///
    /// Sends one counting request per rung: one for the baseline, one more if there is a system
    /// prompt, and one per non-empty tool group. Every rung is a round trip to the provider, so
    /// call this when a breakdown is wanted, not on every turn.
    ///
    /// - Parameters:
    ///   - modelID: The model whose tokenizer applies. Counts from different models are not
    ///     comparable, so a breakdown belongs to one model only.
    ///   - systemPrompt: The system prompt. Nil or empty skips that rung, and the system segment
    ///     is then absent from the result rather than present as zero.
    ///   - messages: The conversation, held identical across every rung so that each difference
    ///     isolates the one segment that changed.
    ///   - toolGroups: Tool sets paired with the segment each is charged to. Measured cumulatively
    ///     from the front, and empty groups are skipped. Two groups naming the same segment add
    ///     together.
    public func breakdown(
        modelID: String,
        systemPrompt: String?,
        messages: [LLMMessage],
        toolGroups: [ToolGroup] = []
    ) async throws -> SegmentBreakdown {
        // Rung 0: the baseline (wrapper + messages). The unavoidable overhead is charged here.
        let bare = try await counter.countInputTokens(
            modelID: modelID, systemPrompt: nil, messages: messages, tools: nil
        )
        var per: [ContextSegment: Int] = [.conversationHistory: bare]
        var prev = bare

        // Rung 1: add the system prompt. Wrapper and messages cancel, leaving its marginal cost.
        let hasSystem = (systemPrompt?.isEmpty == false)
        if hasSystem {
            let sysOnly = try await counter.countInputTokens(
                modelID: modelID, systemPrompt: systemPrompt, messages: messages, tools: nil
            )
            per[.systemPrompt, default: 0] += (sysOnly - prev)
            prev = sysOnly
        }

        // Rungs 2..n: add the tool groups one after another, each measured as its own marginal.
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
