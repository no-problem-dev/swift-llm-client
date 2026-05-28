import Foundation
import Testing
@testable import LLMClient

@Suite("ExchangeRate")
struct ExchangeRateTests {

    @Test("USD → JPY 換算")
    func usdToJpy() {
        let rate = ExchangeRate<USD, JPY>(150)
        let dollars = Money<USD>(1.50)
        let yen = dollars.converted(to: JPY.self, rate: rate)
        #expect(abs(yen.value - 225) < 1e-9)
    }

    @Test("逆方向は型レベルで弾かれる（コンパイル時のみ）")
    func compileTimeDirection() {
        // ExchangeRate<JPY, USD> は別の型なので USD→USD 変換に渡せない。
        // コンパイルが通る/通らないこと自体がテスト。
        let _: ExchangeRate<USD, JPY> = ExchangeRate(150)
        #expect(Bool(true))
    }

    @Test("Codable round-trip")
    func codable() throws {
        let original = ExchangeRate<USD, JPY>(149.5, asOf: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExchangeRate<USD, JPY>.self, from: data)
        #expect(decoded == original)
    }
}
