import Foundation

// MARK: - CurrencyProtocol

/// A currency that a monetary amount can be denominated in.
///
/// Used as the generic parameter of a money value, so amounts in different currencies are different
/// types and cannot be mixed by accident.
public protocol CurrencyProtocol: Sendable, Hashable {
    /// ISO 4217 code of the currency, such as "USD", "JPY" or "EUR".
    static var code: String { get }
    /// Symbol used when formatting an amount, such as "$", "¥" or "€".
    static var symbol: String { get }
    /// How many minor units make one major unit: 100 for dollars, 1 for yen.
    static var minorUnitsPerMajor: Int { get }
    /// Fraction digits used when formatting, unless the caller asks for others.
    static var defaultFractionDigits: Int { get }
}

// MARK: - Money

/// An amount of money carrying its currency in the type.
///
/// Follows the `Measurement` design of `swift-physical-units`: frozen, inlinable, and backed by a
/// `Double`.
///
/// LLM costs are routinely on the order of $0.0001, so the amount is kept as a floating-point value
/// rather than whole minor units, and rounded to the currency's convention only for display.
@frozen
public struct Money<Currency: CurrencyProtocol>: Sendable, Hashable {
    @usableFromInline
    internal let amount: Double

    @inlinable
    public init(_ amount: Double) {
        self.amount = amount
    }

    /// The amount in the currency's major unit: dollars for USD, yen for JPY.
    @inlinable
    public var value: Double { amount }

    /// The amount rounded to whole minor units, such as cents, for display or storage.
    ///
    /// Sub-cent LLM costs round to 0 here, so do not total a run from this.
    @inlinable
    public var minorUnits: Int {
        Int((amount * Double(Currency.minorUnitsPerMajor)).rounded())
    }
}

// MARK: - Arithmetic

extension Money: AdditiveArithmetic {
    @inlinable public static var zero: Money { Money(0) }
    @inlinable public static func + (l: Money, r: Money) -> Money { Money(l.amount + r.amount) }
    @inlinable public static func - (l: Money, r: Money) -> Money { Money(l.amount - r.amount) }
}

extension Money {
    @inlinable public static func * (l: Money, r: Double) -> Money { Money(l.amount * r) }
    @inlinable public static func * (l: Double, r: Money) -> Money { Money(l * r.amount) }
    @inlinable public static func / (l: Money, r: Double) -> Money { Money(l.amount / r) }
}

extension Money: Comparable {
    @inlinable public static func < (l: Money, r: Money) -> Bool { l.amount < r.amount }
}

// MARK: - Codable

extension Money: Codable {
    public init(from decoder: Decoder) throws {
        self.amount = try decoder.singleValueContainer().decode(Double.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(amount)
    }
}

// MARK: - Formatting

extension Money {
    /// Returns the amount as a display string, such as "$1.2345" or "¥150".
    public func formatted(
        minimumFractionDigits: Int = Currency.defaultFractionDigits,
        maximumFractionDigits: Int = Currency.defaultFractionDigits
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Currency.code
        formatter.currencySymbol = Currency.symbol
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: amount))
            ?? "\(Currency.symbol)\(amount)"
    }
}

// MARK: - Standard Currencies

public enum USD: CurrencyProtocol {
    public static let code = "USD"
    public static let symbol = "$"
    public static let minorUnitsPerMajor = 100
    public static let defaultFractionDigits = 4  // LLM costs are counted in units of $0.0001
}

public enum JPY: CurrencyProtocol {
    public static let code = "JPY"
    public static let symbol = "¥"
    public static let minorUnitsPerMajor = 1
    public static let defaultFractionDigits = 0
}

public enum EUR: CurrencyProtocol {
    public static let code = "EUR"
    public static let symbol = "€"
    public static let minorUnitsPerMajor = 100
    public static let defaultFractionDigits = 4
}
