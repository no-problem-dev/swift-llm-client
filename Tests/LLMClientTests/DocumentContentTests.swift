import Foundation
import Testing
@testable import LLMClient

@Test func testDocumentContentCodableRoundTrip() throws {
    let original = DocumentContent.base64(
        Data("PDF-BYTES".utf8),
        mediaType: .pdf,
        title: "report",
        context: "Q2 financials",
        enableCitations: true
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(DocumentContent.self, from: encoded)

    #expect(decoded == original)
    #expect(decoded.mediaType == .pdf)
    #expect(decoded.mimeType == "application/pdf")
    #expect(decoded.title == "report")
    #expect(decoded.context == "Q2 financials")
    #expect(decoded.enableCitations == true)
}

@Test func testMessageContentDocumentCodableRoundTrip() throws {
    let document = DocumentContent.base64(Data("TXT".utf8), mediaType: .plainText)
    let content = LLMMessage.MessageContent.document(document)

    let encoded = try JSONEncoder().encode(content)
    let decoded = try JSONDecoder().decode(LLMMessage.MessageContent.self, from: encoded)

    #expect(decoded == content)
}

@Test func testDocumentMediaTypeInference() {
    #expect(DocumentMediaType.from(fileExtension: "PDF") == .pdf)
    #expect(DocumentMediaType.from(fileExtension: "txt") == .plainText)
    #expect(DocumentMediaType.from(fileExtension: "xyz") == nil)
}

@Test func testDocumentCompatibilityAllProviders() throws {
    let document = DocumentContent.base64(Data("PDF".utf8), mediaType: .pdf)
    for provider in [ProviderType.anthropic, .openai, .gemini] {
        #expect(MediaCompatibility.isSupported(.pdf, by: provider))
        try MediaCompatibility.validate(document, for: provider)
    }
}

@Test func testUserMessageWithDocument() {
    let document = DocumentContent.base64(Data("PDF".utf8), mediaType: .pdf)
    let message = LLMMessage.user("要約して", document: document)

    #expect(message.hasDocument)
    #expect(message.hasMediaContent)
    #expect(message.documents.count == 1)
    #expect(message.content == "要約して")
}
