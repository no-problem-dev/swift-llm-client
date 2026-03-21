import Foundation

// MARK: - StructuredLLMClient

/// 構造化出力に対応した LLM クライアントプロトコル
///
/// `StructuredProtocol` に準拠した任意の型を LLM の出力として取得できます。
/// `@Structured` マクロで定義した型を戻り値として指定するだけで、
/// スキーマの推論・プロンプト注入・JSON パースを自動的に処理します。
///
/// ## 使用例
///
/// ```swift
/// @Structured("都市情報の抽出")
/// struct CityInfo {
///     @StructuredField("都市名")
///     var name: String
///     @StructuredField("人口")
///     var population: Int
/// }
///
/// let result: CityInfo = try await client.generate(
///     input: "東京の人口は約1400万人です",
///     model: .sonnet
/// )
/// ```
public protocol StructuredLLMClient<Model>: Sendable {
    /// このクライアントで使用可能なモデル型
    associatedtype Model: Sendable

    /// 構造化出力を生成（メタデータ付き）
    func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: SystemPrompt?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T>

    /// 会話履歴を含む構造化出力を生成（メタデータ付き）
    func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt?,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> GenerationResult<T>
}

// MARK: - Default Implementations

extension StructuredLLMClient {

    // MARK: - generateWithUsage (default arguments)

    public func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> GenerationResult<T> {
        try await generateWithUsage(
            input: input,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    public func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> GenerationResult<T> {
        try await generateWithUsage(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    // MARK: - generate (result only, delegates to generateWithUsage)

    public func generate<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        let result: GenerationResult<T> = try await generateWithUsage(
            input: input,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return result.result
    }

    public func generate<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        systemPrompt: SystemPrompt? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        let result: GenerationResult<T> = try await generateWithUsage(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return result.result
    }
}
