import Foundation

/// A calendar month, with no day or time.
///
/// Encodes and decodes as a "YYYY-MM" string.
public struct YearMonth: Sendable, Equatable, Hashable, Comparable, Codable, ExpressibleByStringLiteral {
    public let year: Int
    public let month: Int

    /// Creates a month, clamping the month number into range instead of rejecting it.
    ///
    /// - Parameters:
    ///   - year: Four-digit year.
    ///   - month: Month number; anything outside 1 through 12 is clamped to the nearest end.
    public init(year: Int, month: Int) {
        self.year = year
        self.month = max(1, min(12, month))
    }

    // MARK: - ExpressibleByStringLiteral

    /// Creates a month from a "YYYY-MM" string literal.
    ///
    /// A literal that does not parse silently becomes 2000-01, since a literal initializer cannot
    /// fail. Decoding the same text throws instead.
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

    /// The month as a zero-padded ISO 8601 year-month string, such as "2026-08".
    public var formatted: String {
        String(format: "%04d-%02d", year, month)
    }
}
