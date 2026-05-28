import Testing
@testable import LLMClient

@Suite("Money")
struct MoneyTests {

    @Test("演算と比較")
    func arithmetic() {
        let a = Money<USD>(1.5)
        let b = Money<USD>(0.5)
        #expect((a + b).value == 2.0)
        #expect((a - b).value == 1.0)
        #expect((a * 2).value == 3.0)
        #expect((a / 2).value == 0.75)
        #expect(b < a)
        #expect(Money<USD>.zero.value == 0)
    }

    @Test("minorUnits は通貨ごとの倍率で整数化")
    func minorUnits() {
        #expect(Money<USD>(1.234).minorUnits == 123)   // cents
        #expect(Money<JPY>(150).minorUnits == 150)     // 1 円が最小単位
    }

    @Test("USD format は 4 桁、JPY format は 0 桁")
    func formatting() {
        let usd = Money<USD>(0.00123).formatted()
        #expect(usd.contains("0.0012"))
        let jpy = Money<JPY>(150).formatted()
        #expect(jpy.contains("150"))
    }
}
