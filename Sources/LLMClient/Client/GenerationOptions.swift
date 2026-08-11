import Foundation

// MARK: - GenerationOptions

/// The optional settings of one structured-generation request.
///
/// A protocol requirement cannot declare default arguments, so the requirement takes this value and
/// the ergonomic overloads that do have defaults build one. That split is not cosmetic: it keeps the
/// requirement's signature different from the convenience's, which is what makes a conformance that
/// forgets to implement the requirement fail to compile instead of calling the convenience back into
/// itself forever.
public struct GenerationOptions: Sendable, Equatable {
    /// Instructions applied ahead of the input. Providers generally treat this as a stable prefix,
    /// so keeping it byte-identical across calls is what makes prompt caching possible.
    public var systemPrompt: SystemPrompt?

    /// Sampling temperature. Passed through unvalidated; the accepted range differs by provider.
    public var temperature: Double?

    /// Ceiling on output tokens. A ceiling low enough to cut off the JSON leaves the response
    /// undecodable, so leave headroom above the expected result size.
    public var maxTokens: Int?

    /// Creates a set of options, leaving anything unspecified to the provider's default.
    ///
    /// - Parameters:
    ///   - systemPrompt: Instructions applied ahead of the input.
    ///   - temperature: Sampling temperature.
    ///   - maxTokens: Ceiling on output tokens.
    public init(
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}
