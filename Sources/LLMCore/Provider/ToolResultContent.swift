import Foundation

/// What running a tool produced: either its output or the reason it failed.
///
/// Both cases carry a string, because a failed tool is still an answer the model reads and reacts
/// to, not a transport error to throw away.
public enum ToolResultContent: Sendable, Equatable, Codable {
    /// Output of a run that worked.
    case success(String)

    /// Why the run failed, written for the model to read and work around.
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

    /// The string carried by either case, when only the payload matters.
    public var contentValue: String {
        switch self {
        case .success(let content), .failure(let content):
            return content
        }
    }

    public var isError: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
}
