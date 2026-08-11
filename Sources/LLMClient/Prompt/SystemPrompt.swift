import Foundation

// MARK: - SystemPrompt

/// A system prompt assembled from tagged components.
///
/// Built with the DSL, and the order the components are written in is the order the model reads
/// them in — the type never sorts or dedupes. Reordering a prompt therefore changes behavior, so
/// treat the sequence as part of the contract.
///
/// Despite the name this is the prompt type everywhere, not only for the system slot: a chat client
/// renders it into the system field, while `LLMInput` renders the same type into the text of a user
/// message.
///
/// A `SystemPromptMetadata` can be attached for catalogs and UI. It is not rendered, so it never
/// reaches the provider.
///
/// ## Example
///
/// ```swift
/// // Without metadata
/// let prompt = SystemPrompt {
///     PromptComponent.role("Data analysis expert")
///     PromptComponent.objective("Extract user information from text")
///     PromptComponent.context("The input is a social media post written in Japanese")
///
///     PromptComponent.instruction("Strip honorifics from names")
///     PromptComponent.instruction("Extract ages as bare numbers")
///
///     PromptComponent.constraint("Never guess")
///     PromptComponent.important("Return null when the information is missing")
///
///     PromptComponent.example(
///         input: "Hanako Sato (28) lives in Tokyo",
///         output: #"{"name": "Hanako Sato", "age": 28}"#
///     )
/// }
///
/// // With metadata, for registering in a catalog
/// let catalogPrompt = SystemPrompt(
///     "Researcher",
///     description: "Tuned for gathering, analyzing, and synthesizing information",
///     iconName: "magnifyingglass",
///     tags: ["research", "analysis"]
/// ) {
///     PromptComponent.role("expert research assistant")
///     PromptComponent.objective("Gather and synthesize information")
/// }
///
/// let result: UserInfo = try await client.generate(
///     prompt: prompt,
///     model: .sonnet
/// )
/// ```
///
/// ## Rendering
///
/// Each component becomes a one-line XML-style element, and the elements are joined with a blank
/// line in declaration order.
///
/// ```xml
/// <role>Data analysis expert</role>
///
/// <objective>Extract user information from text</objective>
///
/// <context>The input is a social media post written in Japanese</context>
///
/// ...
/// ```
public struct SystemPrompt: Sendable, Equatable, Codable {

    // MARK: - Properties

    /// Catalog and display information, when the prompt was built with any.
    ///
    /// Never rendered: `render()` walks the components only, so metadata cannot change the bytes
    /// sent to the provider and cannot cost tokens or invalidate a cached prompt prefix. It does
    /// take part in equality and encoding, so two prompts that render identically still compare
    /// unequal when their metadata differs.
    public let metadata: SystemPromptMetadata?

    /// The components in the order they were written, which is the order the model reads.
    public let components: [PromptComponent]

    // MARK: - Initializers

    /// Builds a prompt from a DSL block.
    ///
    /// - Parameter builder: A block listing the components, in the order they should be sent.
    ///
    /// ## Example
    /// ```swift
    /// let prompt = SystemPrompt {
    ///     PromptComponent.role("Data analysis expert")
    ///     PromptComponent.objective("Extract information")
    ///     PromptComponent.instruction("Extract the name")
    /// }
    /// ```
    public init(@SystemPromptBuilder _ builder: () -> [PromptComponent]) {
        self.metadata = nil
        self.components = builder()
    }

    /// Builds a prompt that carries catalog metadata.
    ///
    /// The identifier is derived from the name: lowercased, with spaces and underscores turned into
    /// hyphens. Nothing else is sanitized, so any other punctuation in the name survives into the
    /// identifier, and two names that differ only in those characters collide.
    ///
    /// - Parameters:
    ///   - name: The display name, which the identifier is derived from.
    ///   - description: What the prompt is for.
    ///   - iconName: An SF Symbols name.
    ///   - tags: Free-form tags for grouping.
    ///   - builder: A block listing the components, in the order they should be sent.
    ///
    /// ## Example
    /// ```swift
    /// let prompt = SystemPrompt(
    ///     "Researcher",
    ///     description: "Tuned for research and analysis tasks",
    ///     iconName: "magnifyingglass",
    ///     tags: ["research"]
    /// ) {
    ///     PromptComponent.role("expert research assistant")
    /// }
    /// ```
    public init(
        _ name: String,
        description: String,
        iconName: String,
        tags: [String] = [],
        @SystemPromptBuilder _ builder: () -> [PromptComponent]
    ) {
        let id = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        self.metadata = SystemPromptMetadata(
            id: id,
            name: name,
            description: description,
            iconName: iconName,
            tags: tags
        )
        self.components = builder()
    }

    /// Builds a prompt from an array that was assembled elsewhere.
    ///
    /// Use it when the components are computed rather than written out — the constraints a schema
    /// adapter had to drop, for instance.
    ///
    /// - Parameters:
    ///   - components: The components, in the order they should be sent.
    ///   - metadata: Catalog and display information, if any.
    ///
    /// ## Example
    /// ```swift
    /// let components: [PromptComponent] = [
    ///     .objective("Extract information"),
    ///     .instruction("Extract the name")
    /// ]
    /// let prompt = SystemPrompt(components: components)
    /// ```
    public init(components: [PromptComponent], metadata: SystemPromptMetadata? = nil) {
        self.metadata = metadata
        self.components = components
    }

    // MARK: - Rendering

    /// Renders the prompt into the text the provider receives.
    ///
    /// Each component becomes an XML-style element and the elements are joined with a blank line,
    /// in declaration order. Nothing is escaped, and the metadata is left out.
    ///
    /// The result is what a provider hashes for prompt caching, so a prompt that is rebuilt with
    /// different content on every request cannot hit a cached prefix.
    ///
    /// - Returns: The rendered prompt, or an empty string when there are no components.
    public func render() -> String {
        components
            .map { $0.render() }
            .joined(separator: "\n\n")
    }

    /// The prompt as plain text without the tags, for showing to a person.
    ///
    /// Not what the model receives — use `render()` for that.
    public var displayText: String {
        components
            .map { $0.contentPreview }
            .joined(separator: "\n\n")
    }

    // MARK: - Computed Properties

    /// Whether the prompt holds no components at all.
    ///
    /// A prompt whose components carry empty strings is not empty by this measure: it still renders
    /// a run of tags, and providers that reject a blank system prompt will accept it.
    public var isEmpty: Bool {
        components.isEmpty
    }

    /// The number of components, which says nothing about characters or tokens.
    public var count: Int {
        components.count
    }
}

// MARK: - CustomStringConvertible

extension SystemPrompt: CustomStringConvertible {
    public var description: String {
        render()
    }
}

// MARK: - ExpressibleByStringLiteral

extension SystemPrompt: ExpressibleByStringLiteral {
    /// Builds a prompt from a plain string, so a literal can stand in anywhere a prompt is wanted.
    ///
    /// The string becomes a single context component, which means it does not reach the model as
    /// written: it arrives wrapped in a context element. Build the components explicitly when the
    /// exact bytes matter.
    ///
    /// ## Example
    /// ```swift
    /// let prompt: SystemPrompt = "Taro Yamada is 35 years old"
    /// // renders as <context>Taro Yamada is 35 years old</context>
    /// ```
    public init(stringLiteral value: String) {
        self.metadata = nil
        self.components = [.context(value)]
    }
}

// MARK: - SystemPrompt Combination

extension SystemPrompt {
    /// Concatenates two prompts, keeping the metadata of the left one.
    ///
    /// The right-hand components land at the end, so everything the left prompt rendered stays
    /// byte-identical and a provider's cached prefix survives. Appending is therefore the cheap
    /// direction; putting the new material first is not.
    ///
    /// - Parameters:
    ///   - lhs: The prompt that keeps its metadata and renders first.
    ///   - rhs: The prompt appended after it.
    /// - Returns: The concatenated prompt.
    public static func + (lhs: SystemPrompt, rhs: SystemPrompt) -> SystemPrompt {
        SystemPrompt(components: lhs.components + rhs.components, metadata: lhs.metadata)
    }

    /// Appends a single component to the end of a prompt.
    ///
    /// - Parameters:
    ///   - lhs: The prompt, whose metadata is kept.
    ///   - rhs: The component to append.
    /// - Returns: The extended prompt.
    public static func + (lhs: SystemPrompt, rhs: PromptComponent) -> SystemPrompt {
        SystemPrompt(components: lhs.components + [rhs], metadata: lhs.metadata)
    }

    /// Returns a prompt with another prompt's components appended.
    ///
    /// - Parameter other: The prompt to append. Its metadata is discarded.
    public func appending(_ other: SystemPrompt) -> SystemPrompt {
        self + other
    }

    /// Returns a prompt with one more component at the end.
    ///
    /// - Parameter component: The component to append.
    public func appending(_ component: PromptComponent) -> SystemPrompt {
        self + component
    }

    /// Returns a prompt extended with the components a DSL block produces.
    ///
    /// The metadata is carried over, which the concatenation operators do not do for the
    /// right-hand side.
    ///
    /// - Parameter builder: A block listing the components to append.
    public func modified(@SystemPromptBuilder with builder: () -> [PromptComponent]) -> SystemPrompt {
        SystemPrompt(components: components + builder(), metadata: metadata)
    }
}

// MARK: - Filtering and Transformation

extension SystemPrompt {
    /// Returns a prompt holding only the components that satisfy a test.
    ///
    /// Order is preserved, and the metadata comes along even when nothing survives the filter.
    ///
    /// - Parameter predicate: The test each component has to pass.
    public func filter(_ predicate: (PromptComponent) -> Bool) -> SystemPrompt {
        SystemPrompt(components: components.filter(predicate), metadata: metadata)
    }

    /// Returns a prompt holding only the components that render under a given tag.
    ///
    /// Match on the rendered tag rather than the case name; two of them differ, notably
    /// `thinking_step` and `output_constraint`.
    ///
    /// - Parameter tagName: The tag to keep, as it appears in the rendered prompt.
    ///
    /// ## Example
    /// ```swift
    /// let instructions = prompt.components(withTag: "instruction")
    /// ```
    public func components(withTag tagName: String) -> SystemPrompt {
        filter { $0.tagName == tagName }
    }
}

// MARK: - LLMInputProtocol Conformance

extension SystemPrompt: LLMInputProtocol {
    /// The prompt itself, so a bare prompt can be passed wherever an input is expected.
    ///
    /// The conformance carries no media, and going through it renders the prompt into a user
    /// message rather than into the system slot.
    public var prompt: SystemPrompt { self }
}
