import Foundation

// MARK: - ExchangeRate

/// 通貨間の為替レート。
///
/// `From` → `To` の方向を型レベルで固定し、誤った方向の換算をコンパイル時に防ぐ。
/// 内部は「`From` 1 単位あたりの `To` の量」を保持する。
@frozen
public struct ExchangeRate<From: CurrencyProtocol, To: CurrencyProtocol>: Sendable, Hashable, Codable {
    /// 1 `From` = `value` `To`。例: USD→JPY なら 150.0（1 USD = 150 JPY）。
    public let value: Double
    /// レートが取得・確定した時刻。鮮度判定に使う。
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
    /// 別通貨へ換算する。
    @inlinable
    public func converted<To: CurrencyProtocol>(
        to _: To.Type,
        rate: ExchangeRate<Currency, To>
    ) -> Money<To> {
        Money<To>(value * rate.value)
    }
}
