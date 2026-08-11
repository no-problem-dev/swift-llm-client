import Foundation

// MARK: - ToolAnnotations

/// Hints about how a tool behaves, following the MCP tool annotation vocabulary.
///
/// They describe intent — whether a call only reads, may destroy something, is safe to repeat,
/// or reaches outside the host — so a client can decide what to confirm with a person before
/// running it. None of it reaches the model: tool definitions carry the name, description and
/// schema only, so annotations stay on this side of the wire and cost no tokens.
///
/// - Note: Every field is a hint, not a guarantee. Values that came from an untrusted server must
///         not be believed without verification.
///
/// ## Example
///
/// ```swift
/// let annotations = ToolAnnotations(
///     title: "Read file",
///     readOnlyHint: true
/// )
/// ```
public struct ToolAnnotations: Sendable, Equatable {
    /// A human-readable title, for showing the tool rather than for calling it.
    public var title: String?

    /// Whether the tool leaves its environment unchanged.
    ///
    /// Assumed `false` when unset.
    public var readOnlyHint: Bool?

    /// Whether the tool may make destructive updates.
    ///
    /// Meaningful only when the tool is not read-only. Assumed `true` when unset, so an
    /// unannotated write is treated as the dangerous kind.
    public var destructiveHint: Bool?

    /// Whether repeating a call with the same arguments has no further effect.
    ///
    /// Meaningful only when the tool is not read-only. It is what tells a caller whether a
    /// timed-out call can simply be retried. Assumed `false` when unset.
    public var idempotentHint: Bool?

    /// Whether the tool may reach entities outside the host.
    ///
    /// A web search is open world; a memory store is closed world. Assumed `true` when unset.
    public var openWorldHint: Bool?

    public init(
        title: String? = nil,
        readOnlyHint: Bool? = nil,
        destructiveHint: Bool? = nil,
        idempotentHint: Bool? = nil,
        openWorldHint: Bool? = nil
    ) {
        self.title = title
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
        self.idempotentHint = idempotentHint
        self.openWorldHint = openWorldHint
    }

    /// Annotations for a tool that only reads.
    public static let readOnly = ToolAnnotations(readOnlyHint: true)

    /// Annotations for a tool that writes and may destroy what was there.
    public static let destructive = ToolAnnotations(
        readOnlyHint: false,
        destructiveHint: true
    )

    /// Annotations for a destructive write that is safe to repeat with the same arguments.
    public static let idempotentWrite = ToolAnnotations(
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: true
    )

    /// Annotations for a tool confined to the host, such as a memory store.
    public static let closedWorld = ToolAnnotations(openWorldHint: false)
}
