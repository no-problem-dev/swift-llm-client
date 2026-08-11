import Foundation
import Testing
import LLMCore
@testable import LLMMediaKit

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - 背景
//
// downloadData() は remoteURL が nil のとき self をそのまま返し、HTTP ステータスも見ていなかった。
// 前者は「空の動画がダウンロード成功として返る」、後者は「404 の HTML 本文が動画として保存される」。
// どちらも失敗が成功の顔をして通るので、throw させる。

// MARK: - Stub

/// 応答をテストが指定する URLProtocol。ネットワークには出ない。
private final class StubURLProtocol: URLProtocol {
    struct Response: Sendable {
        var statusCode: Int
        var body: Data
    }

    nonisolated(unsafe) static var stub: Response?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = Self.stub, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

// MARK: - Tests

@Suite("GeneratedVideo.downloadData は失敗を投げる", .serialized)
struct GeneratedVideoDownloadTests {

    @Test("remoteURL が無ければ noRemoteURL を投げる（自分自身を返さない）")
    func throwsWhenNoRemoteURL() async throws {
        let video = GeneratedVideo(data: Data())
        await #expect(throws: GeneratedMediaError.self) {
            _ = try await video.downloadData(using: StubURLProtocol.makeSession())
        }
        do {
            _ = try await video.downloadData(using: StubURLProtocol.makeSession())
            Issue.record("投げられなかった")
        } catch let error as GeneratedMediaError {
            guard case .noRemoteURL = error else {
                Issue.record("想定外のエラー: \(error)")
                return
            }
        }
    }

    @Test("404 の本文を動画として取り込まず downloadHTTPStatus を投げる")
    func throwsOnHTTPFailureStatus() async throws {
        StubURLProtocol.stub = .init(statusCode: 404, body: Data("<html>Not Found</html>".utf8))
        defer { StubURLProtocol.stub = nil }

        let video = GeneratedVideo(remoteURL: URL(string: "https://example.com/v.mp4")!)
        do {
            _ = try await video.downloadData(using: StubURLProtocol.makeSession())
            Issue.record("投げられなかった")
        } catch let error as GeneratedMediaError {
            guard case .downloadHTTPStatus(let code) = error else {
                Issue.record("想定外のエラー: \(error)")
                return
            }
            #expect(code == 404)
        }
    }

    @Test("200 なら本文をバイトとして取り込み、他のフィールドを保つ")
    func downloadsOnSuccess() async throws {
        let bytes = Data([0x00, 0x01, 0x02, 0x03])
        StubURLProtocol.stub = .init(statusCode: 200, body: bytes)
        defer { StubURLProtocol.stub = nil }

        let video = GeneratedVideo(
            remoteURL: URL(string: "https://example.com/v.mp4")!,
            duration: 5,
            resolution: .hd720p,
            jobId: "job-1",
            prompt: "a cat"
        )
        let downloaded = try await video.downloadData(using: StubURLProtocol.makeSession())

        #expect(downloaded.data == bytes)
        #expect(downloaded.hasLocalData)
        #expect(downloaded.duration == 5)
        #expect(downloaded.resolution == .hd720p)
        #expect(downloaded.jobId == "job-1")
        #expect(downloaded.prompt == "a cat")
        #expect(downloaded.remoteURL == video.remoteURL)
    }

    @Test("500 も同じく拒否する")
    func throwsOnServerError() async throws {
        StubURLProtocol.stub = .init(statusCode: 500, body: Data("boom".utf8))
        defer { StubURLProtocol.stub = nil }

        let video = GeneratedVideo(remoteURL: URL(string: "https://example.com/v.mp4")!)
        do {
            _ = try await video.downloadData(using: StubURLProtocol.makeSession())
            Issue.record("投げられなかった")
        } catch let error as GeneratedMediaError {
            guard case .downloadHTTPStatus(let code) = error else {
                Issue.record("想定外のエラー: \(error)")
                return
            }
            #expect(code == 500)
        }
    }
}
