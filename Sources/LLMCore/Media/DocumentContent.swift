// swift-llm-client

import Foundation

// MARK: - Document Media Type

/// ドキュメントメディアタイプ
///
/// ドキュメント形式とその MIME タイプ・ファイル拡張子を定義する。
///
/// ## 使用例
/// ```swift
/// let documentType: DocumentMediaType = .pdf
/// print(documentType.fileExtension)  // "pdf"
/// ```
public enum DocumentMediaType: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case pdf = "application/pdf"
    case plainText = "text/plain"

    // MARK: - Properties

    /// ファイル拡張子
    public var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .plainText: return "txt"
        }
    }

    /// MIME タイプ文字列
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// ファイル拡張子からメディアタイプを推論
    ///
    /// - Parameter fileExtension: ファイル拡張子（ドットなし）
    /// - Returns: 対応するメディアタイプ、見つからない場合は nil
    public static func from(fileExtension: String) -> DocumentMediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "pdf": return .pdf
        case "txt", "text": return .plainText
        default: return nil
        }
    }
}

extension DocumentMediaType: MediaType {}

// MARK: - Document Content

/// ドキュメントコンテンツ
///
/// LLM に送信するドキュメント（PDF・テキスト）データを表現する。
///
/// ## サポートされるプロバイダー
/// - **Anthropic**: PDF, テキスト
/// - **OpenAI**: PDF, テキスト
/// - **Gemini**: PDF, テキスト
///
/// ## 使用例
/// ```swift
/// // Base64データから
/// let pdfData = try Data(contentsOf: pdfFileURL)
/// let document = DocumentContent.base64(pdfData, mediaType: .pdf)
///
/// // ファイルパスから（自動推論）
/// let document = try DocumentContent.file(at: "/path/to/report.pdf")
/// ```
public struct DocumentContent: Sendable, Equatable, Codable {
    /// データソース
    public let source: MediaSource

    /// メディアタイプ
    public let mediaType: DocumentMediaType

    /// モデルがファイルを区別するための任意タイトル
    public let title: String?

    /// 任意の文脈ヒント
    public let context: String?

    /// 引用を有効化
    public let enableCitations: Bool

    // MARK: - Initializers

    /// 初期化
    ///
    /// - Parameters:
    ///   - source: データソース
    ///   - mediaType: ドキュメントのMIMEタイプ
    ///   - title: モデルがファイルを区別するための任意タイトル
    ///   - context: 任意の文脈ヒント
    ///   - enableCitations: 引用を有効化（default false）
    public init(
        source: MediaSource,
        mediaType: DocumentMediaType,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) {
        self.source = source
        self.mediaType = mediaType
        self.title = title
        self.context = context
        self.enableCitations = enableCitations
    }

    // MARK: - Convenience Initializers

    /// Base64データから初期化
    ///
    /// - Parameters:
    ///   - data: ドキュメントのバイナリデータ
    ///   - mediaType: ドキュメントのMIMEタイプ
    ///   - title: モデルがファイルを区別するための任意タイトル
    ///   - context: 任意の文脈ヒント
    ///   - enableCitations: 引用を有効化
    /// - Returns: ドキュメントコンテンツ
    public static func base64(
        _ data: Data,
        mediaType: DocumentMediaType,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) -> DocumentContent {
        DocumentContent(
            source: .base64(data),
            mediaType: mediaType,
            title: title,
            context: context,
            enableCitations: enableCitations
        )
    }

    /// URLから初期化
    ///
    /// - Parameters:
    ///   - url: ドキュメントのURL
    ///   - mediaType: ドキュメントのMIMEタイプ
    ///   - title: モデルがファイルを区別するための任意タイトル
    ///   - context: 任意の文脈ヒント
    ///   - enableCitations: 引用を有効化
    /// - Returns: ドキュメントコンテンツ
    public static func url(
        _ url: URL,
        mediaType: DocumentMediaType,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) -> DocumentContent {
        DocumentContent(
            source: .url(url),
            mediaType: mediaType,
            title: title,
            context: context,
            enableCitations: enableCitations
        )
    }

    /// ファイル参照から初期化
    ///
    /// - Parameters:
    ///   - id: File APIのファイルID
    ///   - mediaType: ドキュメントのMIMEタイプ
    ///   - title: モデルがファイルを区別するための任意タイトル
    ///   - context: 任意の文脈ヒント
    ///   - enableCitations: 引用を有効化
    /// - Returns: ドキュメントコンテンツ
    public static func fileReference(
        _ id: String,
        mediaType: DocumentMediaType,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) -> DocumentContent {
        DocumentContent(
            source: .fileReference(id: id),
            mediaType: mediaType,
            title: title,
            context: context,
            enableCitations: enableCitations
        )
    }

    /// ファイルパスから初期化（メディアタイプを拡張子から推論）
    ///
    /// - Parameters:
    ///   - path: ファイルパス
    ///   - title: モデルがファイルを区別するための任意タイトル
    ///   - context: 任意の文脈ヒント
    ///   - enableCitations: 引用を有効化
    /// - Returns: ドキュメントコンテンツ
    /// - Throws: `MediaError.unsupportedFormat` または `MediaError.fileReadError`
    public static func file(
        at path: String,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) throws -> DocumentContent {
        let url = URL(fileURLWithPath: path)
        return try file(at: url, title: title, context: context, enableCitations: enableCitations)
    }

    /// ファイルURLから初期化（メディアタイプを拡張子から推論）
    ///
    /// - Parameters:
    ///   - url: ファイルURL
    ///   - title: モデルがファイルを区別するための任意タイトル
    ///   - context: 任意の文脈ヒント
    ///   - enableCitations: 引用を有効化
    /// - Returns: ドキュメントコンテンツ
    /// - Throws: `MediaError.unsupportedFormat` または `MediaError.fileReadError`
    public static func file(
        at url: URL,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) throws -> DocumentContent {
        let source = try MediaSource.fromFile(at: url)
        let mediaType = try inferMediaType(from: url)
        return DocumentContent(
            source: source,
            mediaType: mediaType,
            title: title,
            context: context,
            enableCitations: enableCitations
        )
    }

    // MARK: - Private

    private static func inferMediaType(from url: URL) throws -> DocumentMediaType {
        let ext = url.pathExtension.lowercased()
        guard let mediaType = DocumentMediaType.from(fileExtension: ext) else {
            throw MediaError.unsupportedFormat(ext)
        }
        return mediaType
    }
}

extension DocumentContent: MediaContentProtocol {
    public var mimeType: String { mediaType.mimeType }
}
