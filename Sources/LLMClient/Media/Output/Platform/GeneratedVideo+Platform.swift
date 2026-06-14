// swift-llm-client
//
// GeneratedVideo のネットワーク I/O 便利機能

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension GeneratedVideo {
    /// リモート URL からデータをダウンロード
    ///
    /// - Returns: ダウンロードされたデータを含む新しい GeneratedVideo
    /// - Throws: ダウンロードに失敗した場合
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
