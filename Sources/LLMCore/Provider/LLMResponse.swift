// LLMResponse.swift
// swift-llm-client

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
    /// レスポンスに含まれる全ての画像を配列で返す。
    /// 画像が含まれていない場合は空の配列を返す。
    public var generatedImages: [GeneratedImage] {
        content.compactMap { $0.generatedImage }
    }

    /// 最初の生成された画像を取得
    ///
    /// レスポンスに含まれる最初の画像を返す。
    /// 画像が含まれていない場合は `nil` を返す。
    public var firstGeneratedImage: GeneratedImage? {
        generatedImages.first
    }

    /// 生成された音声をすべて取得
    ///
    /// レスポンスに含まれる全ての音声を配列で返す。
    /// 音声が含まれていない場合は空の配列を返す。
    public var generatedAudioFiles: [GeneratedAudio] {
        content.compactMap { $0.generatedAudio }
    }

    /// 最初の生成された音声を取得
    ///
    /// レスポンスに含まれる最初の音声を返す。
    /// 音声が含まれていない場合は `nil` を返す。
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
    /// LLM レスポンスに含まれるコンテンツの種類。
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
        /// 画像が含まれる場合に使用する。
        case image(GeneratedImage)

        /// 生成された音声
        ///
        /// TTS（Text-to-Speech）など、レスポンス内にインラインで
        /// 音声が含まれる場合に使用する。
        case audio(GeneratedAudio)

        /// 思考コンテンツ（Extended Thinking）
        ///
        /// Claude の Extended Thinking で生成された思考プロセスを表す。
        /// signature は後続リクエストで思考ブロックを参照するために使用する。
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

