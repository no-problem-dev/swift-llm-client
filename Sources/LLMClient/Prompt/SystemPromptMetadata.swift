import Foundation

// MARK: - SystemPromptMetadata

/// Display information about a system prompt.
///
/// What a catalog, a preset list, or a detail screen needs in order to show a prompt without
/// rendering it. None of it is sent to the provider — a prompt renders its components only — so
/// editing metadata costs no tokens and cannot invalidate a cached prompt prefix.
///
/// ## Example
///
/// ```swift
/// let metadata = SystemPromptMetadata(
///     id: "researcher",
///     name: "Researcher",
///     description: "Tuned for gathering, analyzing, and synthesizing information",
///     iconName: "magnifyingglass",
///     tags: ["research", "analysis"]
/// )
/// ```
public struct SystemPromptMetadata: Sendable, Equatable, Codable, Identifiable, Hashable {

    /// The identifier a list uses to tell one prompt from another.
    ///
    /// Supplied by the caller and never checked for uniqueness. The convenience initializer on the
    /// prompt derives it from the display name.
    public let id: String

    /// The name to show.
    public let name: String

    /// What the prompt is for, in a sentence or two for a catalog entry.
    public let description: String

    /// An SF Symbols name, which is not checked against the symbols that exist.
    public let iconName: String

    /// Free-form tags for grouping and filtering in a catalog.
    public let tags: [String]

    /// Creates the display information for a prompt.
    ///
    /// - Parameters:
    ///   - id: The identifier a list uses; uniqueness is the caller's responsibility.
    ///   - name: The name to show.
    ///   - description: What the prompt is for.
    ///   - iconName: An SF Symbols name.
    ///   - tags: Free-form tags for grouping.
    public init(
        id: String,
        name: String,
        description: String,
        iconName: String,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.tags = tags
    }
}
