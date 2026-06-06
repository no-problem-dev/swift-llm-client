import Foundation

// MARK: - PromptCachePolicy

/// プロンプトキャッシングの方針
///
/// リクエストの「安定プレフィックス」— システムプロンプト・ツール宣言・ツール設定 —
/// をどうキャッシュするかの**意図**を表す、プロバイダー非依存の語彙。
/// 具体的なメカニズムへの変換（lowering）は各プロバイダー実装の責務:
///
/// - Gemini: `cachedContents` リソース（明示キャッシュ）を作成して参照
/// - Anthropic: 安定プレフィックス末尾への `cache_control` ブレークポイント配置
/// - OpenAI など自動キャッシュのみのプロバイダー: `.implicit` と同等に扱う（graceful degradation）
///
/// TTL の解釈はプロバイダーのライフサイクルに従う:
/// Gemini は固定期限（読み取りで延長されず、更新 API で延長）、
/// Anthropic は読み取りごとにスライドする。
///
/// キャッシュの読み書き実績は `TokenUsage.cacheReadTokens` / `cacheCreationTokens` に反映される。
public enum PromptCachePolicy: Sendable, Hashable, Codable {
    /// プロバイダーの暗黙（自動）キャッシュに任せる
    ///
    /// API へキャッシュ指示を送らない。プレフィックスが安定していれば
    /// プロバイダー側の自動キャッシュが効くことがあるが、保証はない。
    case implicit

    /// 安定プレフィックスを明示的にキャッシュする
    ///
    /// - Parameter ttl: キャッシュの生存期間。プロバイダーの粒度に丸められることがある
    case explicitPrefix(ttl: Duration)
}

// MARK: - PromptCacheReleasing

/// 明示キャッシュをサーバー側リソースとして所有するクライアントが適合する
///
/// Gemini のようにキャッシュがストレージ課金されるプロバイダーでは、
/// セッション終了時に解放することで残り TTL 分の課金を止められる。
/// リソースを持たないプロバイダー（Anthropic / OpenAI 等）は適合しなくてよい —
/// 呼び出し側は `as? PromptCacheReleasing` で graceful に分岐する。
public protocol PromptCacheReleasing {
    /// このクライアントが作成したキャッシュリソースを全て解放する
    func releasePromptCaches() async
}
