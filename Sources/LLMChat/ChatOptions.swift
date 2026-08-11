import Foundation
import LLMClient

// MARK: - ChatOptions

/// The optional settings of one conversational turn.
///
/// A protocol requirement cannot declare default arguments, so `chat` takes this value and the
/// ergonomic overloads that do have defaults build one. Keeping the requirement's signature
/// distinct from the convenience's is what makes a conformance that forgets to implement `chat`
/// fail to compile rather than call the convenience back into itself forever.
public struct ChatOptions: Sendable, Equatable {
    /// Instructions applied ahead of the history. Keeping it byte-identical across turns is what
    /// lets a provider cache the prefix.
    public var systemPrompt: String?

    /// Sampling temperature. Passed through unvalidated; the accepted range differs by provider.
    public var temperature: Double?

    /// Ceiling on output tokens. A ceiling low enough to cut the JSON short leaves the response
    /// undecodable, so leave headroom above the expected result size.
    public var maxTokens: Int?

    /// Creates a set of options, leaving anything unspecified to the provider's default.
    ///
    /// - Parameters:
    ///   - systemPrompt: Instructions applied ahead of the history.
    ///   - temperature: Sampling temperature.
    ///   - maxTokens: Ceiling on output tokens.
    public init(
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}
