// LLMMessage.swift
// swift-llm-client

import Foundation

// MARK: - LLMMessage

/// LLM メッセージ
///
/// テキストメッセージに加えて、ツール呼び出しとツール結果もサポートします。
///
/// ## 使用例
///
/// ```swift
/// // テキストメッセージ
/// let userMessage = LLMMessage.user("東京の天気は？")
/// let assistantMessage = LLMMessage.assistant("東京は晴れです。")
///
/// // ツール呼び出し（アシスタントからの応答）
/// let toolCallMessage = LLMMessage.toolUse(
///     id: "call_123",
///     name: "get_weather",
///     input: jsonData
/// )
///
/// // ツール結果（ユーザーからの応答として送信）
/// let toolResultMessage = LLMMessage.toolResult(
///     toolCallId: "call_123",
///     name: "get_weather",
///     content: "晴れ、25度"
/// )
/// ```
public struct LLMMessage: Sendable, Codable {
    /// メッセージの役割
    public let role: Role

    /// メッセージ内容（複合コンテンツ対応）
    public let contents: [MessageContent]

    /// 役割
    public enum Role: String, Sendable, Codable {
        case user
        case assistant
    }

    /// メッセージコンテンツの種類
    public enum MessageContent: Sendable, Equatable, Codable {
        // MARK: - 既存（テキスト・ツール関連）

        /// テキストコンテンツ
        case text(String)

        /// ツール呼び出し（アシスタントが生成）
        case toolUse(id: String, name: String, input: Data)

        /// ツール実行結果（ツール呼び出しへの応答）
        /// - Parameters:
        ///   - toolCallId: 対応するツール呼び出しID
        ///   - name: ツール名（Gemini APIで必須）
        ///   - content: 実行結果（成功または失敗）
        case toolResult(toolCallId: String, name: String, content: ToolResultContent)

        // MARK: - 新規（メディア入力）

        /// 画像コンテンツ
        ///
        /// サポート状況:
        /// - Anthropic: ✓（JPEG, PNG, GIF, WebP）
        /// - OpenAI: ✓（JPEG, PNG, GIF, WebP）
        /// - Gemini: ✓（JPEG, PNG, GIF, WebP, HEIC, HEIF）
        case image(ImageContent)

        /// 音声コンテンツ
        ///
        /// サポート状況:
        /// - Anthropic: ✗
        /// - OpenAI: ✓（WAV, MP3）gpt-4o-audio-preview のみ
        /// - Gemini: ✓（WAV, MP3, AAC, FLAC, OGG, AIFF）
        case audio(AudioContent)

        /// 動画コンテンツ
        ///
        /// サポート状況:
        /// - Anthropic: ✗
        /// - OpenAI: ✗（フレーム分解が必要）
        /// - Gemini: ✓（MP4, AVI, MOV, MKV, WebM, FLV, MPEG, 3GP, WMV）
        case video(VideoContent)

        /// 思考コンテンツ（Extended Thinking）
        ///
        /// Claude の Extended Thinking で生成された思考プロセスを会話履歴に保持するために使用。
        case thinking(text: String, signature: String?)

        // MARK: - Codable

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case id
            case name
            case input
            case toolCallId
            case content
            case imageContent
            case audioContent
            case videoContent
            case signature
        }

        private enum ContentType: String, Codable {
            case text
            case toolUse
            case toolResult
            case image
            case audio
            case video
            case thinking
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(ContentType.self, forKey: .type)

            switch type {
            case .text:
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case .toolUse:
                let id = try container.decode(String.self, forKey: .id)
                let name = try container.decode(String.self, forKey: .name)
                let input = try container.decode(Data.self, forKey: .input)
                self = .toolUse(id: id, name: name, input: input)
            case .toolResult:
                let toolCallId = try container.decode(String.self, forKey: .toolCallId)
                let name = try container.decode(String.self, forKey: .name)
                let content = try container.decode(ToolResultContent.self, forKey: .content)
                self = .toolResult(toolCallId: toolCallId, name: name, content: content)
            case .image:
                let imageContent = try container.decode(ImageContent.self, forKey: .imageContent)
                self = .image(imageContent)
            case .audio:
                let audioContent = try container.decode(AudioContent.self, forKey: .audioContent)
                self = .audio(audioContent)
            case .video:
                let videoContent = try container.decode(VideoContent.self, forKey: .videoContent)
                self = .video(videoContent)
            case .thinking:
                let text = try container.decode(String.self, forKey: .text)
                let signature = try container.decodeIfPresent(String.self, forKey: .signature)
                self = .thinking(text: text, signature: signature)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .text(let text):
                try container.encode(ContentType.text, forKey: .type)
                try container.encode(text, forKey: .text)
            case .toolUse(let id, let name, let input):
                try container.encode(ContentType.toolUse, forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
                try container.encode(input, forKey: .input)
            case .toolResult(let toolCallId, let name, let content):
                try container.encode(ContentType.toolResult, forKey: .type)
                try container.encode(toolCallId, forKey: .toolCallId)
                try container.encode(name, forKey: .name)
                try container.encode(content, forKey: .content)
            case .image(let imageContent):
                try container.encode(ContentType.image, forKey: .type)
                try container.encode(imageContent, forKey: .imageContent)
            case .audio(let audioContent):
                try container.encode(ContentType.audio, forKey: .type)
                try container.encode(audioContent, forKey: .audioContent)
            case .video(let videoContent):
                try container.encode(ContentType.video, forKey: .type)
                try container.encode(videoContent, forKey: .videoContent)
            case .thinking(let text, let signature):
                try container.encode(ContentType.thinking, forKey: .type)
                try container.encode(text, forKey: .text)
                try container.encodeIfPresent(signature, forKey: .signature)
            }
        }
    }

    // MARK: - Initializers

    /// メッセージを初期化（複合コンテンツ）
    public init(role: Role, contents: [MessageContent]) {
        self.role = role
        self.contents = contents
    }

    /// メッセージを初期化（単一テキスト）
    public init(role: Role, content: String) {
        self.role = role
        self.contents = [.text(content)]
    }

    // MARK: - Convenience Properties

    /// テキストコンテンツを取得（後方互換性）
    ///
    /// 複数のテキストブロックがある場合は結合して返します。
    /// テキストがない場合は空文字列を返します。
    public var content: String {
        contents.compactMap { content in
            if case .text(let text) = content {
                return text
            }
            return nil
        }.joined()
    }

    /// ツール呼び出しを含むかどうか
    public var hasToolUse: Bool {
        contents.contains { content in
            if case .toolUse = content { return true }
            return false
        }
    }

    /// ツール結果を含むかどうか
    public var hasToolResult: Bool {
        contents.contains { content in
            if case .toolResult = content { return true }
            return false
        }
    }

    /// ツール呼び出しを取得
    public var toolUses: [(id: String, name: String, input: Data)] {
        contents.compactMap { content in
            if case .toolUse(let id, let name, let input) = content {
                return (id, name, input)
            }
            return nil
        }
    }

    /// ツール結果を取得
    public var toolResults: [(toolCallId: String, name: String, content: ToolResultContent)] {
        contents.compactMap { content in
            if case .toolResult(let id, let name, let resultContent) = content {
                return (id, name, resultContent)
            }
            return nil
        }
    }

    // MARK: - Factory Methods

    /// ユーザーメッセージを作成
    public static func user(_ content: String) -> LLMMessage {
        LLMMessage(role: .user, content: content)
    }

    /// アシスタントメッセージを作成
    public static func assistant(_ content: String) -> LLMMessage {
        LLMMessage(role: .assistant, content: content)
    }

    /// ツール呼び出しメッセージを作成（アシスタント）
    ///
    /// LLM がツールを呼び出すことを決定した際のメッセージ。
    /// 通常は `LLMResponse` から自動的に生成されます。
    ///
    /// - Parameters:
    ///   - id: ツール呼び出しID
    ///   - name: ツール名
    ///   - input: ツール引数（JSON データ）
    public static func toolUse(id: String, name: String, input: Data) -> LLMMessage {
        LLMMessage(role: .assistant, contents: [.toolUse(id: id, name: name, input: input)])
    }

    /// 複数のツール呼び出しを含むメッセージを作成（アシスタント）
    ///
    /// - Parameter toolCalls: ツール呼び出し情報の配列
    public static func toolUses(_ toolCalls: [(id: String, name: String, input: Data)]) -> LLMMessage {
        let contents = toolCalls.map { MessageContent.toolUse(id: $0.id, name: $0.name, input: $0.input) }
        return LLMMessage(role: .assistant, contents: contents)
    }

    /// ツール実行結果メッセージを作成（成功）（ユーザー）
    ///
    /// ツールを実行した結果を LLM に返すためのメッセージ。
    ///
    /// - Parameters:
    ///   - toolCallId: 対応するツール呼び出しID
    ///   - name: ツール名
    ///   - content: 実行結果の文字列
    public static func toolResult(
        toolCallId: String,
        name: String,
        content: String
    ) -> LLMMessage {
        LLMMessage(role: .user, contents: [.toolResult(toolCallId: toolCallId, name: name, content: .success(content))])
    }

    /// ツール実行エラーメッセージを作成（ユーザー）
    ///
    /// ツール実行時のエラーを LLM に返すためのメッセージ。
    ///
    /// - Parameters:
    ///   - toolCallId: 対応するツール呼び出しID
    ///   - name: ツール名
    ///   - error: エラーメッセージ
    public static func toolError(
        toolCallId: String,
        name: String,
        error: String
    ) -> LLMMessage {
        LLMMessage(role: .user, contents: [.toolResult(toolCallId: toolCallId, name: name, content: .failure(error))])
    }

    /// 複数のツール実行結果を含むメッセージを作成（ユーザー）
    ///
    /// - Parameter results: ツール結果情報の配列
    public static func toolResults(_ results: [(toolCallId: String, name: String, content: ToolResultContent)]) -> LLMMessage {
        let contents = results.map {
            MessageContent.toolResult(toolCallId: $0.toolCallId, name: $0.name, content: $0.content)
        }
        return LLMMessage(role: .user, contents: contents)
    }
}

