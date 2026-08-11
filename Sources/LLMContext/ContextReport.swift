import Foundation
import LLMClient

// MARK: - ContextReport

/// How full one agent's context window is, and optionally what is filling it.
///
/// The two figures come from different places and are not interchangeable. Occupancy is exact and
/// free, taken from usage the provider already reported. The breakdown is measured on demand and
/// is an approximation, so treat it as an explanation of the occupancy rather than a second
/// opinion on it: the two need not agree to the token.
public struct ContextReport: Sendable {

    /// How much of the window is in use, always available and exact.
    public let occupancy: ContextOccupancy

    /// What the window is filled with, or nil until a breakdown has been measured.
    ///
    /// Measuring costs token-counting requests, so it stays nil until someone asks for it, and
    /// once measured it ages: the occupancy beside it moves every turn while this does not.
    public var breakdown: SegmentBreakdown?

    public init(occupancy: ContextOccupancy, breakdown: SegmentBreakdown? = nil) {
        self.occupancy = occupancy
        self.breakdown = breakdown
    }
}
