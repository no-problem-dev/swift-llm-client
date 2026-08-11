// MediaError.swift
// swift-llm-client
//
// Created by Claude on 2025-12-20.

import Foundation

// MARK: - Media Error

/// A failure raised while a piece of media is being built or checked locally.
///
/// Everything here happens before a request leaves the process. Rejection by a provider is a
/// separate concern, reported by `ProviderCompatibilityError` in `LLMProviderCompat`, so
/// catching only these cases still leaves provider refusals to handle.
///
/// Three cases — mismatch, missing parameter and invalid URL — are declared for callers and
/// adapters to raise; nothing in this package throws them.
///
/// ## Example
/// ```swift
/// do {
///     let image = try ImageContent.file(at: "/path/to/image.xyz")
/// } catch MediaError.unsupportedFormat(let format) {
///     print("Unsupported format: \(format)")
/// } catch MediaError.fileReadError(let error) {
///     print("File read error: \(error)")
/// }
/// ```
public enum MediaError: Error, Sendable, Equatable {
    /// A file extension that none of the media format enumerations recognize.
    ///
    /// The payload is the offending extension, not a MIME type. This says nothing about any
    /// provider: it is raised purely because the extension was not in this package's tables.
    case unsupportedFormat(String)

    /// Inline data larger than the byte budget it was checked against.
    ///
    /// The budget is whatever the caller passed in, not a limit read from a provider, and both
    /// figures count undecoded bytes rather than the longer Base64 form.
    case sizeLimitExceeded(size: Int, maxSize: Int)

    /// A local file could not be read, wrapping the underlying failure.
    ///
    /// Equality compares the wrapped error only by its localized description, so two unrelated
    /// failures that print the same message compare equal.
    case fileReadError(any Error & Sendable)

    /// Bytes that could not be interpreted, such as a string that is not valid Base64.
    case invalidMediaData(String)

    /// A declared media type that disagrees with the content it describes.
    ///
    /// Nothing in this package raises it, because no format sniffing happens here. It exists
    /// for code that does verify content to report the disagreement in the same currency.
    case mediaTypeMismatch(expected: String, actual: String)

    /// A required value was absent.
    ///
    /// Raised by callers and provider adapters rather than by this package.
    case missingRequiredParameter(String)

    /// A string that could not be parsed as a URL.
    ///
    /// Raised by callers and provider adapters rather than by this package.
    case invalidURL(String)

    // MARK: - Equatable

    public static func == (lhs: MediaError, rhs: MediaError) -> Bool {
        switch (lhs, rhs) {
        case (.unsupportedFormat(let l), .unsupportedFormat(let r)):
            return l == r
        case (.sizeLimitExceeded(let ls, let lm), .sizeLimitExceeded(let rs, let rm)):
            return ls == rs && lm == rm
        case (.fileReadError(let l), .fileReadError(let r)):
            return l.localizedDescription == r.localizedDescription
        case (.invalidMediaData(let l), .invalidMediaData(let r)):
            return l == r
        case (.mediaTypeMismatch(let le, let la), .mediaTypeMismatch(let re, let ra)):
            return le == re && la == ra
        case (.missingRequiredParameter(let l), .missingRequiredParameter(let r)):
            return l == r
        case (.invalidURL(let l), .invalidURL(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - LocalizedError

extension MediaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported media format: \(format)"

        case .sizeLimitExceeded(let size, let maxSize):
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .binary)
            let maxStr = ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .binary)
            return "Media size (\(sizeStr)) exceeds limit (\(maxStr))"

        case .fileReadError(let error):
            return "Failed to read file: \(error.localizedDescription)"

        case .invalidMediaData(let reason):
            return "Invalid media data: \(reason)"

        case .mediaTypeMismatch(let expected, let actual):
            return "Media type mismatch: expected \(expected), got \(actual)"

        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"

        case .invalidURL(let urlString):
            return "Invalid URL: \(urlString)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .unsupportedFormat:
            return "The media format is not supported by any provider"
        case .sizeLimitExceeded:
            return "The media file is too large for the provider's limits"
        case .fileReadError:
            return "The file could not be read from disk"
        case .invalidMediaData:
            return "The media data is corrupted or in an invalid format"
        case .mediaTypeMismatch:
            return "The media type does not match the expected type"
        case .missingRequiredParameter:
            return "A required parameter was not provided"
        case .invalidURL:
            return "The URL string could not be parsed"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Convert the file to a supported format. Format '\(format)' is not supported."
        case .sizeLimitExceeded(_, let maxSize):
            let maxStr = ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .binary)
            return "Reduce the file size to under \(maxStr) or use the File API for larger files."
        case .fileReadError:
            return "Check that the file exists and you have permission to read it."
        case .invalidMediaData:
            return "Ensure the media data is valid and not corrupted."
        case .mediaTypeMismatch:
            return "Provide media content with the correct type."
        case .missingRequiredParameter(let param):
            return "Provide a value for '\(param)'."
        case .invalidURL:
            return "Provide a valid URL string."
        }
    }
}

// MARK: - CustomNSError

extension MediaError: CustomNSError {
    public static var errorDomain: String {
        "LLMClient.MediaError"
    }

    public var errorCode: Int {
        switch self {
        case .unsupportedFormat: return 1001
        case .sizeLimitExceeded: return 1002
        case .fileReadError: return 1004
        case .invalidMediaData: return 1005
        case .mediaTypeMismatch: return 1006
        case .missingRequiredParameter: return 1007
        case .invalidURL: return 1008
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [
            NSLocalizedDescriptionKey: errorDescription ?? "Unknown error"
        ]
        if let reason = failureReason {
            info[NSLocalizedFailureReasonErrorKey] = reason
        }
        if let suggestion = recoverySuggestion {
            info[NSLocalizedRecoverySuggestionErrorKey] = suggestion
        }
        return info
    }
}

// MARK: - Convenience

extension MediaError {
    /// Throws when a measured size exceeds a budget the caller supplies.
    ///
    /// It knows nothing about provider limits: both figures come from the caller, so the budget
    /// has to be looked up elsewhere and passed in.
    ///
    /// - Parameters:
    ///   - size: The measured size in bytes.
    ///   - maxSize: The budget in bytes.
    /// - Throws: `MediaError.sizeLimitExceeded`, carrying both figures.
    public static func validateSize(_ size: Int, maxSize: Int) throws {
        if size > maxSize {
            throw MediaError.sizeLimitExceeded(size: size, maxSize: maxSize)
        }
    }
}
