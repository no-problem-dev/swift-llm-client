// swift-llm-client

import Foundation

// MARK: - Document Media Type

/// A document format a model can accept as input, with its MIME type and file extension.
///
/// Both cases are accepted by every provider, which makes documents the one media kind with no
/// provider gaps. The cost profiles differ sharply though: plain text is charged as text, while
/// a PDF is charged per page.
///
/// ## Example
/// ```swift
/// let documentType: DocumentMediaType = .pdf
/// print(documentType.fileExtension)  // "pdf"
/// ```
public enum DocumentMediaType: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case pdf = "application/pdf"
    case plainText = "text/plain"

    // MARK: - Properties

    /// The lowercase file extension, without a leading dot.
    ///
    /// Plain text yields `txt`, though `from(fileExtension:)` also accepts `text`.
    public var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .plainText: return "txt"
        }
    }

    /// The MIME type sent to the provider, which is also the case's raw value and encoded form.
    public var mimeType: String { rawValue }

    // MARK: - Inference

    /// Returns the document format for a file extension, or nil when the extension is unknown.
    ///
    /// Only `pdf`, `txt` and `text` are recognized. Text-shaped extensions such as `md`, `csv`
    /// or `json` are rejected even though their bytes would be perfectly readable as plain text.
    ///
    /// - Parameter fileExtension: An extension with no leading dot.
    public static func from(fileExtension: String) -> DocumentMediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "pdf": return .pdf
        case "txt", "text": return .plainText
        default: return nil
        }
    }
}

extension DocumentMediaType: MediaType {}

// MARK: - Document Content

/// A PDF or text document to send to a model as input.
///
/// Anthropic, OpenAI and Gemini all accept both formats, so documents are the one media kind
/// that needs no provider branching. A PDF is charged by page rather than by file size, because
/// each page contributes both a rendered image and its extracted text — a hundred-page report
/// costs far more than its megabytes suggest.
///
/// Beyond the bytes, a document carries a title, a context hint and a citations flag. These are
/// prompt-shaping metadata rather than transport details, and they are what separates this type
/// from the other media contents.
///
/// ## Example
/// ```swift
/// // Inline bytes
/// let pdfData = try Data(contentsOf: pdfFileURL)
/// let document = DocumentContent.base64(pdfData, mediaType: .pdf)
///
/// // From a path, with the format inferred from the extension
/// let document = try DocumentContent.file(at: "/path/to/report.pdf")
/// ```
public struct DocumentContent: Sendable, Equatable, Codable {
    public let source: MediaSource

    /// The format the provider is told the bytes are in.
    ///
    /// Nothing verifies it against the actual content; at most a file extension was consulted.
    public let mediaType: DocumentMediaType

    /// A short name the model sees, used to tell several attached documents apart.
    ///
    /// Worth setting whenever more than one document is in a message, since it is how the model
    /// can refer to one of them in its answer.
    public let title: String?

    /// A hint about what the document is or how to read it, shown to the model alongside it.
    ///
    /// It is part of the prompt and counts toward input tokens like any other text.
    public let context: String?

    /// Whether the model is asked to cite passages from this document in its answer.
    ///
    /// Off by default. Provider compatibility checking ignores this flag entirely, so asking
    /// for citations from a provider that has no document citations fails late, at the API, or
    /// not at all.
    public let enableCitations: Bool

    // MARK: - Initializers

    /// Creates a document from an already-built source and its declared format.
    ///
    /// - Parameters:
    ///   - source: Where the bytes come from.
    ///   - mediaType: The format the provider is told the bytes are in.
    ///   - title: A short name the model sees, used to tell several documents apart.
    ///   - context: A hint about what the document is, shown to the model alongside it.
    ///   - enableCitations: Whether to ask the model to cite passages from this document.
    public init(
        source: MediaSource,
        mediaType: DocumentMediaType,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) {
        self.source = source
        self.mediaType = mediaType
        self.title = title
        self.context = context
        self.enableCitations = enableCitations
    }

    // MARK: - Convenience Initializers

    /// Creates a document whose bytes travel inline in the request.
    ///
    /// Despite the name it takes raw data, not a Base64 string; encoding happens at send time
    /// and inflates the payload by roughly a third.
    ///
    /// - Parameters:
    ///   - data: The undecoded document bytes.
    ///   - mediaType: The format the provider is told the bytes are in.
    ///   - title: A short name the model sees, used to tell several documents apart.
    ///   - context: A hint about what the document is, shown to the model alongside it.
    ///   - enableCitations: Whether to ask the model to cite passages from this document.
    public static func base64(
        _ data: Data,
        mediaType: DocumentMediaType,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) -> DocumentContent {
        DocumentContent(
            source: .base64(data),
            mediaType: mediaType,
            title: title,
            context: context,
            enableCitations: enableCitations
        )
    }

    /// Creates a document the provider is expected to fetch for itself.
    ///
    /// The bytes are never read here, so the URL has to be reachable from the provider's
    /// network rather than only from this process.
    ///
    /// - Parameters:
    ///   - url: A publicly reachable HTTP or HTTPS URL.
    ///   - mediaType: The format the provider is told the bytes are in.
    ///   - title: A short name the model sees, used to tell several documents apart.
    ///   - context: A hint about what the document is, shown to the model alongside it.
    ///   - enableCitations: Whether to ask the model to cite passages from this document.
    public static func url(
        _ url: URL,
        mediaType: DocumentMediaType,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) -> DocumentContent {
        DocumentContent(
            source: .url(url),
            mediaType: mediaType,
            title: title,
            context: context,
            enableCitations: enableCitations
        )
    }

    /// Creates a document that points at a file already uploaded to a provider's file API.
    ///
    /// Worth using for a long PDF consulted across many turns, since the bytes are uploaded
    /// once. Identifiers are not portable between providers.
    ///
    /// - Parameters:
    ///   - id: A provider-scoped file identifier, such as a Gemini `files/...` name.
    ///   - mediaType: The format the provider is told the bytes are in.
    ///   - title: A short name the model sees, used to tell several documents apart.
    ///   - context: A hint about what the document is, shown to the model alongside it.
    ///   - enableCitations: Whether to ask the model to cite passages from this document.
    public static func fileReference(
        _ id: String,
        mediaType: DocumentMediaType,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) -> DocumentContent {
        DocumentContent(
            source: .fileReference(id: id),
            mediaType: mediaType,
            title: title,
            context: context,
            enableCitations: enableCitations
        )
    }

    /// Reads a local document file, taking its format from the path extension.
    ///
    /// The whole file is loaded into memory and only the extension is consulted, so a Markdown
    /// or CSV file is refused here even though its bytes are plain text — read it yourself and
    /// build an inline source with the plain-text format if that is what you want.
    ///
    /// - Parameters:
    ///   - path: A local filesystem path.
    ///   - title: A short name the model sees, used to tell several documents apart.
    ///   - context: A hint about what the document is, shown to the model alongside it.
    ///   - enableCitations: Whether to ask the model to cite passages from this document.
    /// - Throws: `MediaError.unsupportedFormat` when the extension is not a known document
    ///   extension, or `MediaError.fileReadError` when the file cannot be read.
    public static func file(
        at path: String,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) throws -> DocumentContent {
        let url = URL(fileURLWithPath: path)
        return try file(at: url, title: title, context: context, enableCitations: enableCitations)
    }

    /// Reads a document from a file URL, taking its format from the path extension.
    ///
    /// This always produces an inline source. Passing an HTTP URL downloads it synchronously
    /// rather than deferring the fetch to the provider.
    ///
    /// - Parameters:
    ///   - url: A file URL.
    ///   - title: A short name the model sees, used to tell several documents apart.
    ///   - context: A hint about what the document is, shown to the model alongside it.
    ///   - enableCitations: Whether to ask the model to cite passages from this document.
    /// - Throws: `MediaError.unsupportedFormat` when the extension is not a known document
    ///   extension, or `MediaError.fileReadError` when the file cannot be read.
    public static func file(
        at url: URL,
        title: String? = nil,
        context: String? = nil,
        enableCitations: Bool = false
    ) throws -> DocumentContent {
        let source = try MediaSource.fromFile(at: url)
        let mediaType = try inferMediaType(from: url)
        return DocumentContent(
            source: source,
            mediaType: mediaType,
            title: title,
            context: context,
            enableCitations: enableCitations
        )
    }

    // MARK: - Private

    private static func inferMediaType(from url: URL) throws -> DocumentMediaType {
        let ext = url.pathExtension.lowercased()
        guard let mediaType = DocumentMediaType.from(fileExtension: ext) else {
            throw MediaError.unsupportedFormat(ext)
        }
        return mediaType
    }
}

extension DocumentContent: MediaContentProtocol {
    public var mimeType: String { mediaType.mimeType }
}
