import Foundation
import LLMClient

// MARK: - ContextBarSegment

/// One band of a stacked context bar: what it represents, its tokens, and its share of the bar.
public struct ContextBarSegment: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case systemPrompt, toolDefinitions, mcpToolDefinitions, memoryFiles
        case latestToolResults, conversationHistory
        case cached, fresh   // Occupancy mode, used when there is no breakdown
        case free
    }

    public let kind: Kind
    public let tokens: Int

    /// Share of the bar, from 0 to 1, taken against the window size.
    ///
    /// Where the window size is unknown the shares are taken against the tokens in use instead, so
    /// the bands fill the bar completely and none of them means "this fraction of the window".
    public let fraction: Double

    public init(kind: Kind, tokens: Int, fraction: Double) {
        self.kind = kind
        self.tokens = tokens
        self.fraction = fraction
    }
}

// MARK: - ContextBarLayout

/// Turns a context report into the bands of a stacked bar, with no dependency on any UI framework.
///
/// Which bands appear depends on what the report holds. With a breakdown, one band per category
/// that has tokens. Without one, the occupancy is split into cached and fresh, since cached tokens
/// fill the window just the same but cost far less. A free band is added only when the window size
/// is known.
///
/// When the window size is unknown the shares are taken against the tokens in use instead, so the
/// bar fills completely and no free band appears. It shows the proportions, not a percentage of a
/// window nobody knows the size of, which is a figure this deliberately declines to invent.
public struct ContextBarLayout: Sendable, Hashable {

    public let segments: [ContextBarSegment]
    public let windowSize: Int?
    public let usedTokens: Int

    /// Lays out the bands for a report.
    ///
    /// - Parameter report: The context state to draw. Its breakdown, if it has one, decides
    ///   whether the bar shows categories or the cached and fresh split.
    public init(report: ContextReport) {
        let occ = report.occupancy
        let window = occ.windowSize
        self.windowSize = window
        self.usedTokens = occ.used

        // Denominator: the window when it is known, otherwise the tokens in use, floored at 1.
        let denom = Double(window ?? max(occ.used, 1))
        func frac(_ tokens: Int) -> Double { denom > 0 ? Double(tokens) / denom : 0 }

        var result: [ContextBarSegment] = []

        if let breakdown = report.breakdown {
            // Breakdown mode: one band per category, in a fixed display order.
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
            // Occupancy mode: fresh and cached apart, since cached tokens fill the window as much
            // but cost far less.
            let cached = occ.cacheReadTokens + occ.cacheCreationTokens
            let fresh = max(0, occ.used - cached)
            if fresh > 0 {
                result.append(ContextBarSegment(kind: .fresh, tokens: fresh, fraction: frac(fresh)))
            }
            if cached > 0 {
                result.append(ContextBarSegment(kind: .cached, tokens: cached, fraction: frac(cached)))
            }
        }

        // The free band, only when the window size is known.
        if let free = occ.free, free > 0 {
            result.append(ContextBarSegment(kind: .free, tokens: free, fraction: frac(free)))
        }

        self.segments = result
    }
}
