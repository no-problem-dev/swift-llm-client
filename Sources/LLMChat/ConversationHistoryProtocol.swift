import Foundation
import LLMClient

// MARK: - ConversationHistoryProtocol

/// 会話履歴を管理するプロトコル
///
/// LLM との会話履歴を Actor で保護された状態として管理する。
/// 履歴はモデルやクライアントから独立しているため、
/// 同じ履歴を異なるモデルで継続できる。
///
/// ## 概要
///
/// このプロトコルの責務：
///
/// - メッセージ履歴の保存と取得
/// - トークン使用量の累積追跡
/// - イベントストリームによる変更通知
///
/// ## 使用例
///
/// ```swift
/// let history = ConversationHistory()
///
/// // Claude で会話開始
/// let claude = AnthropicClient(apiKey: "...")
/// let result1: CityInfo = try await claude.chat(
///     "日本の首都は？",
///     history: history,
///     model: .sonnet
/// )
///
/// // 同じ履歴で GPT に切り替え
/// let openai = OpenAIClient(apiKey: "...")
/// let result2: PopulationInfo = try await openai.chat(
///     "その都市の人口は？",
///     history: history,
///     model: .gpt4o
/// )
/// ```
///
/// ## カスタム実装
///
/// このプロトコルを実装することで、以下のようなカスタム履歴管理が可能：
///
/// - 永続化対応の履歴（CoreData、ファイル保存など）
/// - 圧縮・要約機能付きの履歴
/// - 制限付きの履歴（最大メッセージ数など）
///
/// ## スレッドセーフティ
///
/// このプロトコルは `Actor` を要求するため、
/// すべての実装は自動的にスレッドセーフになる。
public protocol ConversationHistoryProtocol: Actor, Sendable {
    // MARK: - State Access

    /// 現在のメッセージ履歴を取得
    ///
    /// ユーザーとアシスタントのメッセージが時系列順に格納されている。
    func getMessages() -> [LLMMessage]

    /// 累計トークン使用量を取得
    ///
    /// この履歴を使用したすべての API 呼び出しの
    /// トークン使用量の合計を返す。
    func getTotalUsage() -> TokenUsage

    /// 会話のターン数
    ///
    /// ユーザーとアシスタントのメッセージペア数を返す。
    var turnCount: Int { get }

    // MARK: - State Mutation

    /// メッセージを追加
    ///
    /// メッセージを履歴に追加し、イベントストリームに通知する。
    ///
    /// - Parameter message: 追加するメッセージ
    func append(_ message: LLMMessage)

    /// トークン使用量を累積
    ///
    /// API 呼び出しのトークン使用量を累計に加算し、
    /// イベントストリームに通知する。
    ///
    /// - Parameter usage: 追加するトークン使用量
    func addUsage(_ usage: TokenUsage)

    /// 履歴をクリア
    ///
    /// すべてのメッセージとトークン使用量をリセットし、
    /// イベントストリームに `.cleared` を通知する。
    func clear()

    /// エラーイベントを発火
    ///
    /// API 呼び出しでエラーが発生した場合に、
    /// イベントストリームに `.error` を通知する。
    ///
    /// - Parameter error: 発生したエラー
    func emitError(_ error: LLMError)

    // MARK: - Event Stream

    /// イベントストリーム
    ///
    /// 履歴の変更（メッセージ追加、クリアなど）を
    /// AsyncStream として購読できる。
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// Task {
    ///     for await event in history.eventStream {
    ///         switch event {
    ///         case .userMessage(let msg):
    ///             updateUI(msg)
    ///         case .assistantMessage(let msg):
    ///             updateUI(msg)
    ///         case .usageUpdated(let usage):
    ///             updateTokenCounter(usage)
    ///         case .cleared:
    ///             resetUI()
    ///         case .error(let error):
    ///             showError(error)
    ///         }
    ///     }
    /// }
    /// ```
    nonisolated var eventStream: AsyncStream<ConversationEvent> { get }
}
