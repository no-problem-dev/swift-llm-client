import Foundation

// MARK: - ExchangeRate

/// A rate for converting one currency into another.
///
/// The direction is fixed in the type, so converting the wrong way round is a compile error. What is
/// stored is how much of the target currency one unit of the source is worth.
@frozen
public struct ExchangeRate<From: CurrencyProtocol, To: CurrencyProtocol>: Sendable, Hashable, Codable {
    /// How many units of the target currency one unit of the source buys. USD to JPY is 150.0 when
    /// one dollar is 150 yen.
    public let value: Double
    /// When the rate was obtained. Use it to decide whether the rate is still fresh enough to trust.
    public let asOf: Date

    @inlinable
    public init(_ value: Double, asOf: Date = Date()) {
        precondition(value > 0, "Exchange rate must be positive")
        self.value = value
        self.asOf = asOf
    }
}

// MARK: - Money conversion

extension Money {
    /// Converts the amount into another currency.
    @inlinable
    public func converted<To: CurrencyProtocol>(
        to _: To.Type,
        rate: ExchangeRate<Currency, To>
    ) -> Money<To> {
        Money<To>(value * rate.value)
    }
}
