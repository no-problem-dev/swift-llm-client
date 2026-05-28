import Foundation

// MARK: - LLMResponse

/// LLM からの統一レスポンス形式
public struct LLMResponse: Sendable {
    /// レスポンスコンテンツ
    public let content: [ContentBlock]

    /// 使用されたモデル
    public let model: String

    /// 使用トークン数
    public let usage: TokenUsage

    /// 停止理由
    public let stopReason: StopReason?

    /// レスポンスを初期化
    public init(
        content: [ContentBlock],
        model: String,
        usage: TokenUsage,
        stopReason: StopReason? = nil
    ) {
        self.content = content
        self.model = model
        self.usage = usage
        self.stopReason = stopReason
    }

    // MARK: - Convenience Accessors

    /// すべてのテキストコンテンツを結合して取得
    public var text: String {
        content.compactMap { $0.text }.joined()
    }

    /// すべての思考テキストを結合して取得
    public var thinkingText: String {
        content.compactMap { $0.thinkingText }.joined()
    }

    /// 生成された画像をすべて取得
    ///
    /// レスポンスに含まれるすべての画像を配列で返します。
    /// 画像が含まれていない場合は空の配列を返します。
    public var generatedImages: [GeneratedImage] {
        content.compactMap { $0.generatedImage }
    }

    /// 最初の生成された画像を取得
    ///
    /// レスポンスに含まれる最初の画像を返します。
    /// 画像が含まれていない場合は nil を返します。
    public var firstGeneratedImage: GeneratedImage? {
        generatedImages.first
    }

    /// 生成された音声をすべて取得
    ///
    /// レスポンスに含まれるすべての音声を配列で返します。
    /// 音声が含まれていない場合は空の配列を返します。
    public var generatedAudioFiles: [GeneratedAudio] {
        content.compactMap { $0.generatedAudio }
    }

    /// 最初の生成された音声を取得
    ///
    /// レスポンスに含まれる最初の音声を返します。
    /// 音声が含まれていない場合は nil を返します。
    public var firstGeneratedAudio: GeneratedAudio? {
        generatedAudioFiles.first
    }

    /// レスポンスに画像が含まれているかどうか
    public var hasImages: Bool {
        content.contains { $0.generatedImage != nil }
    }

    /// レスポンスに音声が含まれているかどうか
    public var hasAudio: Bool {
        content.contains { $0.generatedAudio != nil }
    }

    /// レスポンスにメディア（画像または音声）が含まれているかどうか
    public var hasMedia: Bool {
        hasImages || hasAudio
    }

    /// コンテンツブロック
    ///
    /// LLM レスポンスに含まれるコンテンツの種類を表現します。
    ///
    /// ## コンテンツの種類
    /// - `text`: テキストコンテンツ
    /// - `toolUse`: ツール呼び出し（LLM がツールを使用したい場合）
    /// - `image`: 生成された画像（Gemini のインライン画像生成など）
    /// - `audio`: 生成された音声（TTS など）
    public enum ContentBlock: Sendable {
        /// テキストコンテンツ
        case text(String)

        /// ツール呼び出し
        case toolUse(id: String, name: String, input: Data)

        /// 生成された画像
        ///
        /// Gemini のマルチモーダル出力など、レスポンス内にインラインで
        /// 画像が含まれる場合に使用されます。
        case image(GeneratedImage)

        /// 生成された音声
        ///
        /// TTS（Text-to-Speech）など、レスポンス内にインラインで
        /// 音声が含まれる場合に使用されます。
        case audio(GeneratedAudio)

        /// 思考コンテンツ（Extended Thinking）
        ///
        /// Claude の Extended Thinking で生成された思考プロセスを表します。
        /// signature は後続リクエストで思考ブロックを参照するために使用されます。
        case thinking(text: String, signature: String?)

        // MARK: - Convenience Accessors

        /// テキストコンテンツを取得（text ブロックの場合のみ）
        public var text: String? {
            if case .text(let value) = self {
                return value
            }
            return nil
        }

        /// 生成された画像を取得（image ブロックの場合のみ）
        public var generatedImage: GeneratedImage? {
            if case .image(let image) = self {
                return image
            }
            return nil
        }

        /// 生成された音声を取得（audio ブロックの場合のみ）
        public var generatedAudio: GeneratedAudio? {
            if case .audio(let audio) = self {
                return audio
            }
            return nil
        }

        /// 思考テキストを取得（thinking ブロックの場合のみ）
        public var thinkingText: String? {
            if case .thinking(let text, _) = self {
                return text
            }
            return nil
        }

        /// ツール使用の入力を JSON としてデコード
        public func toolInput<T: Decodable>(as type: T.Type) throws -> T? {
            guard case .toolUse(_, _, let data) = self else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        }
    }

    /// 停止理由
    public enum StopReason: String, Sendable {
        case endTurn = "end_turn"
        case maxTokens = "max_tokens"
        case stopSequence = "stop_sequence"
        case toolUse = "tool_use"
        case modelContextWindowExceeded = "model_context_window_exceeded"
    }
}

// TokenUsage は Cost/TokenUsage.swift に分離。

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

// MARK: - LLMError

/// LLM API エラー
public enum LLMError: Error, Sendable {
    /// 認証エラー（無効な API キー）
    case unauthorized

    /// レート制限超過
    case rateLimitExceeded

    /// 無効なリクエスト
    case invalidRequest(String)

    /// モデルが見つからない
    case modelNotFound(String)

    /// サーバーエラー
    case serverError(Int, String)

    /// ネットワークエラー
    case networkError(Error)

    /// 空のレスポンス
    case emptyResponse

    /// 無効なエンコーディング
    case invalidEncoding

    /// デコードエラー
    case decodingFailed(Error)

    /// モデルがプロバイダーに対応していない
    case modelNotSupported(model: String, provider: String)

    /// 構造化出力がサポートされていない
    case structuredOutputNotSupported(model: String)

    /// メディアタイプがプロバイダーでサポートされていない
    ///
    /// 音声や動画など、特定のプロバイダーでサポートされていないメディアが
    /// メッセージに含まれている場合に発生します。
    ///
    /// - Parameters:
    ///   - mediaType: サポートされていないメディアタイプ（例: "audio", "video"）
    ///   - provider: プロバイダー名（例: "Anthropic", "OpenAI"）
    case mediaNotSupported(mediaType: String, provider: String)

    /// コンテンツがブロックされた（安全性フィルター）
    case contentBlocked(reason: String?)

    /// 最大トークン数に達した
    case maxTokensReached

    /// タイムアウト
    case timeout

    /// 不明なエラー
    case unknown(Error)
}

extension LLMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid API key or unauthorized access"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .emptyResponse:
            return "Empty response from the API"
        case .invalidEncoding:
            return "Invalid text encoding in response"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .modelNotSupported(let model, let provider):
            return "Model \(model) is not supported by \(provider)"
        case .structuredOutputNotSupported(let model):
            return "Structured output is not supported by model: \(model)"
        case .mediaNotSupported(let mediaType, let provider):
            return "\(mediaType.capitalized) input is not supported by \(provider)"
        case .contentBlocked(let reason):
            return "Content blocked by safety filter\(reason.map { ": \($0)" } ?? "")"
        case .maxTokensReached:
            return "Maximum token limit reached"
        case .timeout:
            return "Request timed out"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
