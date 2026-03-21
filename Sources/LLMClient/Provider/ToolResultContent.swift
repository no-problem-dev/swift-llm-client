import Foundation

/// ツール実行結果のコンテンツを表現する enum
///
/// ツール呼び出しの成功または失敗を型安全に表現します。
public enum ToolResultContent: Sendable, Equatable, Codable {
    /// 成功した実行結果
    case success(String)

    /// 失敗した実行結果
    case failure(String)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case content
    }

    private enum ContentType: String, Codable {
        case success
        case failure
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        let content = try container.decode(String.self, forKey: .content)

        switch type {
        case .success:
            self = .success(content)
        case .failure:
            self = .failure(content)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .success(let content):
            try container.encode(ContentType.success, forKey: .type)
            try container.encode(content, forKey: .content)
        case .failure(let content):
            try container.encode(ContentType.failure, forKey: .type)
            try container.encode(content, forKey: .content)
        }
    }

    // MARK: - Convenience

    /// コンテンツの文字列値を取得
    public var contentValue: String {
        switch self {
        case .success(let content), .failure(let content):
            return content
        }
    }

    /// 失敗を示すかどうか
    public var isError: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
}
