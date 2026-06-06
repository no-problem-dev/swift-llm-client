import Foundation
import Testing
@testable import LLMClient

@Suite("PromptCachePolicy")
struct PromptCachePolicyTests {

    @Test("Codable ラウンドトリップ")
    func codableRoundTrip() throws {
        let policies: [PromptCachePolicy] = [
            .implicit,
            .explicitPrefix(ttl: .seconds(3600)),
        ]
        for policy in policies {
            let data = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(PromptCachePolicy.self, from: data)
            #expect(decoded == policy)
        }
    }

    @Test("ttl が異なれば別ポリシー")
    func ttlDistinguishesPolicies() {
        #expect(PromptCachePolicy.explicitPrefix(ttl: .seconds(300)) != .explicitPrefix(ttl: .seconds(3600)))
        #expect(PromptCachePolicy.explicitPrefix(ttl: .seconds(300)) != .implicit)
    }

    @Test("LLMRequest の既定は implicit")
    func requestDefaultsToImplicit() {
        let request = LLMRequest(model: .gemini(.flash25), messages: [])
        #expect(request.cachePolicy == .implicit)
    }
}
