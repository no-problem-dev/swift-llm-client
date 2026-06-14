import Foundation

// MARK: - TokenUsage

/// LLM API のトークン使用量。
///
/// **セマンティクス契約**（プロバイダー Converter はこの契約に従って正規化する責務を負う）:
/// - `inputTokens` は **キャッシュ込みの総入力トークン数**
///   - Anthropic の生レスポンス値は cache 抜きの「fresh のみ」なので Converter で合算して正規化する
///   - OpenAI / Gemini の生レスポンスは既にキャッシュ込み総量なので生値をそのまま使う
/// - `outputTokens` は **可視出力 + reasoning を含む総出力トークン数**
///   - `reasoningTokens` は `outputTokens` のサブセット
/// - `cacheReadTokens` / `cacheCreationTokens` は `inputTokens` のサブセット
///   - `freshInputTokens = inputTokens - cacheRead - cacheCreation`
public struct TokenUsage: Sendable, Hashable, Codable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let reasoningTokens: Int?
    public let cacheReadTokens: Int?
    public let cacheCreationTokens: Int?
    public let cacheTier: CacheTier?

    /// キャッシュ読出も書込も発生しなかった、純粋な新規入力トークン。
    @inlinable
    public var freshInputTokens: Int {
        max(0, inputTokens - (cacheReadTokens ?? 0) - (cacheCreationTokens ?? 0))
    }

    /// 可視出力のみ（reasoning を除いた）トークン数。
    @inlinable
    public var visibleOutputTokens: Int {
        max(0, outputTokens - (reasoningTokens ?? 0))
    }

    /// 入出力合算（reasoning は outputTokens 込みなので二重カウントしない）。
    @inlinable
    public var totalTokens: Int { inputTokens + outputTokens }

    public init(
        inputTokens: Int,
        outputTokens: Int,
        reasoningTokens: Int? = nil,
        cacheReadTokens: Int? = nil,
        cacheCreationTokens: Int? = nil,
        cacheTier: CacheTier? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheTier = cacheTier
    }
}

// MARK: - CacheTier

/// プロンプトキャッシュの TTL 種別。
public enum CacheTier: String, Sendable, Hashable, Codable {
    /// 短期 TTL（Anthropic = 5 分、OpenAI/Gemini の通常キャッシュも `.short` で表現）
    case short
    /// 長期 TTL（Anthropic = 1 時間）
    case long
}

// MARK: - Aggregation

extension TokenUsage {
    public static var zero: TokenUsage {
        TokenUsage(inputTokens: 0, outputTokens: 0)
    }

    /// 2 つの TokenUsage を合算する。
    /// `cacheTier` は集計結果には保持しない（ステップ単位で異なるため）。
    public func adding(_ other: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens,
            reasoningTokens: Self.optionalSum(reasoningTokens, other.reasoningTokens),
            cacheReadTokens: Self.optionalSum(cacheReadTokens, other.cacheReadTokens),
            cacheCreationTokens: Self.optionalSum(cacheCreationTokens, other.cacheCreationTokens),
            cacheTier: nil
        )
    }

    private static func optionalSum(_ a: Int?, _ b: Int?) -> Int? {
        switch (a, b) {
        case (nil, nil): return nil
        case (let x?, nil): return x
        case (nil, let y?): return y
        case (let x?, let y?): return x + y
        }
    }
}
