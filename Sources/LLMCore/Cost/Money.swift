import Foundation

// MARK: - CurrencyProtocol

/// 通貨プロトコル。
///
/// `Money<Currency>` のジェネリックパラメータとして使用。
/// 通貨の異なる金額同士はコンパイル時に区別される。
public protocol CurrencyProtocol: Sendable, Hashable {
    /// ISO 4217 通貨コード（"USD", "JPY", "EUR" など）
    static var code: String { get }
    /// 表示記号（"$", "¥", "€" など）
    static var symbol: String { get }
    /// 1 メジャー = いくつのマイナー単位か（USD: 100, JPY: 1）
    static var minorUnitsPerMajor: Int { get }
    /// 表示時のデフォルト小数桁数
    static var defaultFractionDigits: Int { get }
}

// MARK: - Money

/// 通貨単位付きの金額。
///
/// `swift-physical-units` の `Measurement` 設計に倣い、
/// `@frozen` + `@inlinable` + 内部 Double 保持で実装。
///
/// LLM コスト計算は $0.0001 オーダーの超低額が頻出するため、
/// 整数 minor unit ではなく Double 表現を使う。表示時のみ通貨慣習で丸める。
@frozen
public struct Money<Currency: CurrencyProtocol>: Sendable, Hashable {
    @usableFromInline
    internal let amount: Double

    @inlinable
    public init(_ amount: Double) {
        self.amount = amount
    }

    /// 通貨の主要単位での値（USD ならドル、JPY なら円）。
    @inlinable
    public var value: Double { amount }

    /// 最小通貨単位（cent / 銭）に変換した整数値。表示や DB 保存用。
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
    /// 表示用文字列（"$1.2345" / "¥150"）。
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
    public static let defaultFractionDigits = 4  // LLM コストは $0.0001 単位
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
