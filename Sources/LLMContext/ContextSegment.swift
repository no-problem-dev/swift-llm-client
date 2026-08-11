import Foundation
import LLMClient
import LLMTool

// MARK: - ContextSegment

/// A category of content that takes up room in the context window. Provider-independent.
public enum ContextSegment: String, Sendable, Hashable, CaseIterable, Codable {
    /// The system prompt, measured without the per-request overhead.
    case systemPrompt
    /// Definitions of the built-in tools, resent in full on every request.
    case toolDefinitions
    /// Definitions of tools reached through MCP servers, kept apart because a server added to a
    /// session can enlarge them without anything in the app changing.
    case mcpToolDefinitions
    /// Memory and project files carried into the prompt. Nothing charges to it unless a caller
    /// asks for it explicitly.
    case memoryFiles
    /// The conversation, and with it the per-request overhead no request can avoid.
    ///
    /// The baseline every other segment is measured against, which is why the provider's hidden
    /// per-request wrapper is charged here rather than spread across the others.
    case conversationHistory
    /// Tool results from the most recent turn. Folded into the conversation unless a caller asks
    /// for them to be measured on their own.
    case latestToolResults
}

// MARK: - ToolGroup

/// A set of tools together with the segment its tokens are charged to.
///
/// Built-in tools go to the tool-definitions segment, MCP tools to the MCP one. Groups are
/// measured cumulatively in the order given, so each group's figure is the cost of adding it on
/// top of the groups before it. Reordering the groups can therefore move a few boundary tokens
/// between them.
public struct ToolGroup: Sendable {
    public let segment: ContextSegment
    public let tools: ToolSet

    public init(segment: ContextSegment, tools: ToolSet) {
        self.segment = segment
        self.tools = tools
    }
}

// MARK: - SegmentBreakdown

/// Tokens attributed to each category of a context window.
///
/// **Invariant**: the per-segment figures sum exactly to the total. They are built by differencing
/// counts rather than counted separately, which is what makes the sum add up — and what makes the
/// check worth running, since a mismatch means something was double-counted or dropped.
public struct SegmentBreakdown: Sendable, Hashable {
    /// Tokens per category. A category that was not measured is absent rather than zero.
    public let perSegment: [ContextSegment: Int]

    /// Tokens for the whole request with everything included, the figure the parts must sum to.
    public let totalMeasured: Int

    public init(perSegment: [ContextSegment: Int], totalMeasured: Int) {
        self.perSegment = perSegment
        self.totalMeasured = totalMeasured
    }

    /// Returns the tokens charged to a segment, or zero when it was not measured.
    ///
    /// Zero is therefore ambiguous: it means either nothing or nothing measured. Read `perSegment`
    /// directly to tell the two apart.
    public func tokens(for segment: ContextSegment) -> Int {
        perSegment[segment] ?? 0
    }

    /// Whether the per-segment figures still sum to the total.
    ///
    /// A self-check on the measurement rather than a property of the data: false means the
    /// attribution is wrong somewhere, and the figures should not be shown as an explanation of
    /// the total.
    public var isConsistent: Bool {
        perSegment.values.reduce(0, +) == totalMeasured
    }
}
