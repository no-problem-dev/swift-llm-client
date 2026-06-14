import Foundation
import LLMClient

// MARK: - TokenCounting

/// system + tools + messages の入力トークン数を数える port（抽象）。
///
/// **設計方針**: トークン数の算出はプロバイダ固有（Anthropic は `/v1/messages/count_tokens`、
/// ローカルモデルは自前トークナイザ）であり、汎用ローカルトークナイザは存在しない。
/// よって「数える能力」をプロバイダの adapter に委ねる port として定義する（脱プロバイダ）。
///
/// この port は system+tools+messages が揃う最下層（LLMTool）に置く
/// （`LLMRequest` 自体は tools を持たず、tools は LLMTool 層で合流するため）。
///
/// 実装（adapter）は `LLMCloudAnthropic` 等が提供し、`SegmentBreakdownEngine` が
/// 差分減算でカテゴリ別内訳を算出する際に利用する。
public protocol TokenCounting: Sendable {

    /// 与えられた system / tools / messages の合計入力トークン数を返す。
    ///
    /// - Note: 実装は API レスポンスに付随する `usage` ではなく、送信前見積もり
    ///   （`count_tokens` 等）を返す。adapter は **送信時と同一の変換パス**を通すこと
    ///   （cache_control 配置・tool schema・system ブロックを一致させ、見積りと実リクエストを乖離させない）。
    func countInputTokens(
        modelID: String,
        systemPrompt: String?,
        messages: [LLMMessage],
        tools: ToolSet?
    ) async throws -> Int
}
