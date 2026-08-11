// swift-llm-client
//
// Fetching the bytes of a video that lives on a provider's servers.

import Foundation
import LLMCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension GeneratedVideo {
    /// Fetches the video from its remote URL and returns a copy holding the bytes.
    ///
    /// Do this while the provider's link is still live; those URLs expire. The whole video is read
    /// into memory at once, so a long clip costs its full size in RAM.
    ///
    /// Every way this can fail throws. A value with no remote URL has nothing to fetch, and a
    /// non-success HTTP status carries an error page rather than media, so neither is allowed to
    /// come back looking like a downloaded video.
    ///
    /// - Parameter session: The session to fetch with. Injectable so a caller can supply its own
    ///   configuration, and so the failure paths can be tested without a network.
    /// - Returns: A copy carrying the downloaded bytes, with every other field preserved.
    /// - Throws: `GeneratedMediaError.noRemoteURL` when there is no link to fetch,
    ///   `GeneratedMediaError.downloadHTTPStatus` when the provider answers with a non-success
    ///   status, or `GeneratedMediaError.downloadError` wrapping a transport failure.
    public func downloadData(using session: URLSession = .shared) async throws -> GeneratedVideo {
        guard let url = remoteURL else {
            throw GeneratedMediaError.noRemoteURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw GeneratedMediaError.downloadError(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GeneratedMediaError.downloadHTTPStatus(code: http.statusCode)
        }

        return GeneratedVideo(
            data: data,
            format: format,
            remoteURL: remoteURL,
            duration: duration,
            resolution: resolution,
            jobId: jobId,
            prompt: prompt
        )
    }
}
