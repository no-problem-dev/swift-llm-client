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
    /// into memory at once, so a long clip costs its full size in RAM. A video with no remote URL
    /// is returned untouched rather than treated as an error, which means an empty video can come
    /// back empty — check for local data afterwards instead of assuming success.
    ///
    /// - Returns: A copy carrying the downloaded bytes, with every other field preserved.
    /// - Throws: `GeneratedMediaError.downloadError` wrapping the transport error if the fetch
    ///   fails. A non-success HTTP status is not treated as a failure: the response body is taken
    ///   as the video.
    public func downloadData() async throws -> GeneratedVideo {
        guard let url = remoteURL else {
            return self
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return GeneratedVideo(
                data: data,
                format: format,
                remoteURL: remoteURL,
                duration: duration,
                resolution: resolution,
                jobId: jobId,
                prompt: prompt
            )
        } catch {
            throw GeneratedMediaError.downloadError(error)
        }
    }
}
