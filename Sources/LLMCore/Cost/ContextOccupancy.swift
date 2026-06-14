import Foundation

// MARK: - ContextOccupancy

/// コンテキストウィンドウの占有状態。
///
/// 直近リクエストの `TokenUsage`（= API レスポンスに付随する正確値）から、
/// 追加 API コールなしに算出できる「ライブ占有メーター」の値オブジェクト。
///
/// **設計方針**:
/// - `promptTokens` は `TokenUsage.inputTokens`（キャッシュ込み総量に正規化済の契約）をそのまま占有とする。
///   cacheRead / cacheCreation も占有はするため総量から差し引かない（コストが安いだけ）。
/// - `windowSize` が `nil`（モデルプロファイル未定義）の場合、`free` / `usedFraction` は `nil` を返す。
///   占有率を 0 や捏造値でごまかさない（silent fallback の排除）。呼び出し側は絶対値のみ表示する。
/// - reserve（出力予約）/ buffer（compaction 予約）は呼び出し側のポリシー。純粋値型はそれを受け取るだけ。
///
/// ACP (`session/update` の `usage_update`) へは `used` → `used`、`windowSize` → `size` で直接マップする。
public struct ContextOccupancy: Sendable, Hashable {

    /// コンテキストウィンドウ総サイズ（トークン）。未定義モデルでは `nil`。
    public let windowSize: Int?

    /// 入力プロンプトの総占有（= キャッシュ込み総入力トークン）。
    public let promptTokens: Int

    /// プロンプトキャッシュ読出分（`promptTokens` のサブセット）。
    public let cacheReadTokens: Int

    /// プロンプトキャッシュ書込分（`promptTokens` のサブセット）。
    public let cacheCreationTokens: Int

    /// キャッシュを介さない純新規入力（`promptTokens` のサブセット）。
    public let freshInputTokens: Int

    /// 直近応答の出力トークン。
    public let outputTokens: Int

    /// 出力のために予約するトークン（ポリシー）。`free` の算出にのみ影響。
    public let outputReserve: Int

    /// compaction / 安全余白として予約するトークン（ポリシー）。`free` の算出にのみ影響。
    public let compactionBuffer: Int

    // MARK: - Designated init

    public init(
        windowSize: Int?,
        promptTokens: Int,
        cacheReadTokens: Int,
        cacheCreationTokens: Int,
        freshInputTokens: Int,
        outputTokens: Int,
        outputReserve: Int,
        compactionBuffer: Int
    ) {
        self.windowSize = windowSize
        self.promptTokens = promptTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.freshInputTokens = freshInputTokens
        self.outputTokens = outputTokens
        self.outputReserve = outputReserve
        self.compactionBuffer = compactionBuffer
    }

    // MARK: - Convenience init from usage

    /// `TokenUsage` から占有を導出する。
    ///
    /// - Parameters:
    ///   - usage: 直近リクエストの使用量。
    ///   - windowSize: コンテキストウィンドウ総サイズ（未定義なら `nil`）。
    ///   - outputReserve: 出力予約（既定 0）。
    ///   - compactionBuffer: compaction 予約（既定 0）。
    public init(
        usage: TokenUsage,
        windowSize: Int?,
        outputReserve: Int = 0,
        compactionBuffer: Int = 0
    ) {
        self.init(
            windowSize: windowSize,
            promptTokens: usage.inputTokens,
            cacheReadTokens: usage.cacheReadTokens ?? 0,
            cacheCreationTokens: usage.cacheCreationTokens ?? 0,
            freshInputTokens: usage.freshInputTokens,
            outputTokens: usage.outputTokens,
            outputReserve: outputReserve,
            compactionBuffer: compactionBuffer
        )
    }

    /// 占有総量のみが分かっている場合の初期化（cache 内訳なし）。
    ///
    /// ACP `usage_update`（`used` / `size`）や、現在のコンテキストサイズスナップショットから
    /// 占有を構築する用途。`used` は全量を `freshInputTokens` として扱う。
    public init(
        used: Int,
        windowSize: Int?,
        outputReserve: Int = 0,
        compactionBuffer: Int = 0
    ) {
        self.init(
            windowSize: windowSize,
            promptTokens: used,
            cacheReadTokens: 0,
            cacheCreationTokens: 0,
            freshInputTokens: used,
            outputTokens: 0,
            outputReserve: outputReserve,
            compactionBuffer: compactionBuffer
        )
    }

    /// `ModelProfile` からウィンドウサイズと出力予約（= `maxOutputTokens`）を解決して導出する。
    ///
    /// `outputReserve` を明示しない場合、モデルの `maxOutputTokens` を予約として用いる
    /// （「出力に使う分は実質使えない容量」という保守的かつ正直な既定）。
    public init(
        usage: TokenUsage,
        profile: ModelProfile,
        outputReserve: Int? = nil,
        compactionBuffer: Int = 0
    ) {
        self.init(
            usage: usage,
            windowSize: profile.contextWindow,
            outputReserve: outputReserve ?? (profile.maxOutputTokens ?? 0),
            compactionBuffer: compactionBuffer
        )
    }

    // MARK: - Derived

    /// 占有トークン（ACP `used` 相当）。
    @inlinable
    public var used: Int { promptTokens }

    /// 使用可能な空き容量。`windowSize` が `nil` の場合は `nil`。
    ///
    /// `windowSize - used - outputReserve - compactionBuffer` を 0 でクランプ。
    @inlinable
    public var free: Int? {
        guard let windowSize else { return nil }
        return max(0, windowSize - promptTokens - outputReserve - compactionBuffer)
    }

    /// 占有率（0.0–1.0+）。`windowSize` が `nil` または 0 以下の場合は `nil`。
    @inlinable
    public var usedFraction: Double? {
        guard let windowSize, windowSize > 0 else { return nil }
        return Double(promptTokens) / Double(windowSize)
    }

    /// ウィンドウ上限を超過しているか（`windowSize` 未定義なら `false`）。
    @inlinable
    public var isOverLimit: Bool {
        guard let windowSize else { return false }
        return promptTokens > windowSize
    }
}
