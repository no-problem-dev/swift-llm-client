import Testing
import Foundation
@testable import LLMClient

@Suite("ModelProfile")
struct ModelProfileTests {

    // MARK: - Codable Round-trip

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = ModelProfile(
            summary: "高速・低コストのバランス型",
            modelFamily: "Qwen",
            parameterCount: "4B",
            toolCallSupport: .excellent,
            japaneseSupport: .good,
            modalities: [.text, .code, .vision],
            pricing: .flat(inputPerMTok: 3.0, outputPerMTok: 15.0, cacheReadPerMTok: 0.30),
            quantization: "4bit",
            inferenceSpeed: .medium
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelProfile.self, from: data)

        #expect(decoded == original)
        #expect(decoded.summary == "高速・低コストのバランス型")
        #expect(decoded.modelFamily == "Qwen")
        #expect(decoded.parameterCount == "4B")
        #expect(decoded.toolCallSupport == .excellent)
        #expect(decoded.japaneseSupport == .good)
        #expect(decoded.modalities.contains(.text))
        #expect(decoded.modalities.contains(.code))
        #expect(decoded.modalities.contains(.vision))
        #expect(decoded.pricing?.tiers.first?.inputPerMTok == 3.0)
        #expect(decoded.pricing?.cacheReadPerMTok == 0.30)
        #expect(decoded.quantization == "4bit")
        #expect(decoded.inferenceSpeed == .medium)
    }

    @Test("Codable round-trip with nil optional fields")
    func codableRoundTripWithNils() throws {
        let original = ModelProfile(
            summary: "Cloud model",
            modelFamily: "Claude",
            toolCallSupport: .excellent,
            japaneseSupport: .excellent,
            modalities: [.text]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelProfile.self, from: data)

        #expect(decoded == original)
        #expect(decoded.parameterCount == nil)
        #expect(decoded.pricing == nil)
        #expect(decoded.quantization == nil)
        #expect(decoded.inferenceSpeed == nil)
    }

    // MARK: - ToolCallSupport Comparable

    @Test("ToolCallSupport ordering is correct")
    func toolCallSupportOrdering() {
        #expect(ToolCallSupport.unsupported < .basic)
        #expect(ToolCallSupport.basic < .good)
        #expect(ToolCallSupport.good < .excellent)
        #expect(ToolCallSupport.excellent > .unsupported)
    }

    @Test("ToolCallSupport comparison with >= for badges")
    func toolCallSupportBadgeComparison() {
        #expect(ToolCallSupport.excellent >= .good)
        #expect(ToolCallSupport.good >= .good)
        #expect(!(ToolCallSupport.basic >= .good))
        #expect(!(ToolCallSupport.unsupported >= .good))
    }

    // MARK: - LanguageSupport Comparable

    @Test("LanguageSupport ordering is correct")
    func languageSupportOrdering() {
        #expect(LanguageSupport.unsupported < .basic)
        #expect(LanguageSupport.basic < .good)
        #expect(LanguageSupport.good < .excellent)
    }

    // MARK: - Hashable

    @Test("equal profiles have same hash")
    func equalProfilesSameHash() {
        let a = ModelProfile(
            summary: "Test",
            modelFamily: "Test",
            toolCallSupport: .good,
            japaneseSupport: .basic,
            modalities: [.text]
        )
        let b = ModelProfile(
            summary: "Test",
            modelFamily: "Test",
            toolCallSupport: .good,
            japaneseSupport: .basic,
            modalities: [.text]
        )
        #expect(a.hashValue == b.hashValue)
    }

    // MARK: - Pricing Codable

    @Test("Pricing Codable round-trip")
    func pricingCodableRoundTrip() throws {
        let original = Pricing.flat(
            inputPerMTok: 5,
            outputPerMTok: 25,
            cacheReadPerMTok: 0.50,
            cacheWriteShortPerMTok: 6.25,
            cacheWriteLongPerMTok: 10
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Pricing.self, from: data)
        #expect(decoded == original)
    }
}
