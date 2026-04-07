import Foundation

/// 年月を表現する値型
///
/// "YYYY-MM" 形式でコーディング/デコードされます。
public struct YearMonth: Sendable, Equatable, Hashable, Comparable, Codable, ExpressibleByStringLiteral {
    public let year: Int
    public let month: Int

    /// YearMonth を初期化
    ///
    /// - Parameters:
    ///   - year: 年（4桁）
    ///   - month: 月（1-12）
    public init(year: Int, month: Int) {
        self.year = year
        self.month = max(1, min(12, month))
    }

    // MARK: - ExpressibleByStringLiteral

    /// "YYYY-MM" 形式の文字列リテラルから初期化
    public init(stringLiteral value: String) {
        let components = value.split(separator: "-").map(String.init)
        if components.count == 2,
           let year = Int(components[0]),
           let month = Int(components[1]) {
            self.year = year
            self.month = max(1, min(12, month))
        } else {
            self.year = 2000
            self.month = 1
        }
    }

    // MARK: - Comparable

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        return lhs.month < rhs.month
    }

    public static func == (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.year == rhs.year && lhs.month == rhs.month
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        let components = dateString.split(separator: "-").map(String.init)
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected date in format YYYY-MM"
            )
        }

        self.year = year
        self.month = max(1, min(12, month))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let dateString = String(format: "%04d-%02d", year, month)
        try container.encode(dateString)
    }

    // MARK: - Convenience

    /// ISO 8601 形式の文字列を返す
    public var formatted: String {
        String(format: "%04d-%02d", year, month)
    }
}
