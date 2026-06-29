import Foundation
import LLMClient

// MARK: - ToolResult

/// ツール実行の結果
///
/// ツールの `call()` メソッドから返される結果を表す。
/// テキスト、構造化データ（JSON）、またはエラーを表現できる。
///
/// ## 使用例
///
/// ```swift
/// // テキスト結果
/// return .text("東京: 晴れ、25°C")
///
/// // 構造化データ
/// let data = WeatherData(temp: 25, condition: "sunny")
/// return try ToolResult.encoded(data)
///
/// // エラー
/// return .error("API rate limit exceeded")
///
/// // テキスト + メディア（画像など）
/// return .textWithMedia("Image loaded", media: [imageContent])
/// ```
public enum ToolResult: Sendable, Equatable {
    /// テキスト形式の結果
    case text(String)

    /// JSON エンコードされた構造化データ
    case json(Data)

    /// エラーメッセージ
    ///
    /// ツール実行は成功したが処理内でエラーが発生した場合に使用する。
    /// 例: API 呼び出しの失敗、データが見つからない、など
    case error(String)

    /// テキスト + メディアコンテンツ付き結果
    ///
    /// 画像などのメディアを LLM に直接渡す場合に使用する。
    /// テキスト部分は LLM へのツール結果として、メディアは追加コンテンツとして注入される。
    case textWithMedia(String, media: [ImageContent])

    // MARK: - Factory Methods

    /// Encodable な値から JSON 結果を作成
    ///
    /// - Parameter value: JSON エンコード可能な値
    /// - Returns: JSON エンコードされた ToolResult
    /// - Throws: エンコードエラー
    ///
    /// ```swift
    /// let weather = WeatherData(temp: 25, condition: "sunny")
    /// return try ToolResult.encoded(weather)
    /// ```
    public static func encoded<T: Encodable>(_ value: T) throws -> ToolResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(value)
        return .json(data)
    }

    // MARK: - Conversion

    /// 結果を文字列として取得
    ///
    /// - `text`: そのまま返す
    /// - `json`: UTF-8 文字列としてデコード
    /// - `error`: エラーメッセージを返す
    public var stringValue: String {
        switch self {
        case .text(let string):
            return string
        case .json(let data):
            return String(data: data, encoding: .utf8) ?? ""
        case .error(let message):
            return "Error: \(message)"
        case .textWithMedia(let text, _):
            return text
        }
    }

    /// エラーかどうか
    public var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// メディアコンテンツ（存在する場合）
    public var mediaContents: [ImageContent] {
        if case .textWithMedia(_, let media) = self {
            return media
        }
        return []
    }
}

// MARK: - ToolResultConvertible

/// ToolResult に変換可能な型が準拠するプロトコル
///
/// このプロトコルに準拠することでツールの戻り値として使用できる。
/// 標準的な型（`String`、`Int`、`Bool` など）は自動的に準拠している。
///
/// ## 使用例
///
/// ```swift
/// struct WeatherInfo: ToolResultConvertible, Encodable {
///     let temperature: Int
///     let condition: String
///
///     func toToolResult() throws -> ToolResult {
///         return try ToolResult.encoded(self)
///     }
/// }
/// ```
public protocol ToolResultConvertible {
    /// ToolResult に変換
    ///
    /// - Returns: 変換された ToolResult
    /// - Throws: 変換中のエラー
    func toToolResult() throws -> ToolResult
}

// MARK: - Standard Type Conformances

extension String: ToolResultConvertible {
    public func toToolResult() throws -> ToolResult {
        .text(self)
    }
}

extension Int: ToolResultConvertible {
    public func toToolResult() throws -> ToolResult {
        .text(String(self))
    }
}

extension Double: ToolResultConvertible {
    public func toToolResult() throws -> ToolResult {
        .text(String(self))
    }
}

extension Bool: ToolResultConvertible {
    public func toToolResult() throws -> ToolResult {
        .text(String(self))
    }
}

extension Array: ToolResultConvertible where Element: Encodable {
    public func toToolResult() throws -> ToolResult {
        try ToolResult.encoded(self)
    }
}

extension Dictionary: ToolResultConvertible where Key == String, Value: Encodable {
    public func toToolResult() throws -> ToolResult {
        try ToolResult.encoded(self)
    }
}

// MARK: - ToolResult Conformance

extension ToolResult: ToolResultConvertible {
    public func toToolResult() throws -> ToolResult {
        self
    }
}

// MARK: - Codable Types

/// Encodable な型に ToolResultConvertible 準拠を提供するラッパー
///
/// 任意の `Encodable` な型を `ToolResult` に変換する際に使用する。
///
/// ```swift
/// let weather = WeatherData(temp: 25)
/// return try JSONToolResult(weather).toToolResult()
/// ```
public struct JSONToolResult<T: Encodable & Sendable>: ToolResultConvertible, Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }

    public func toToolResult() throws -> ToolResult {
        try ToolResult.encoded(value)
    }
}
