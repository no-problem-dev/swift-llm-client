import Foundation
import Testing
import LLMCore
@testable import LLMMediaKit

#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - 背景
//
// 失敗の理由が呼び出し元に届かない二か所。
// save(to:) は生の CocoaError を投げるので `catch GeneratedMediaError` が素通りし、
// audioPlayer は try? で理由を捨てるので「コンテナの無い PCM」と「途中で切れたバイト列」を
// 呼び出し元が区別できない。

// MARK: - save(to:)

@Suite("GeneratedMedia.save は書き込み失敗を自分の型で報告する")
struct GeneratedMediaSaveTests {
    private func image() -> GeneratedImage {
        GeneratedImage(data: Data([0x89, 0x50, 0x4E, 0x47]), format: .png)
    }

    @Test("書き込めない場所へ保存すると saveError になる")
    func writeFailureIsSaveError() {
        // 存在しない中間ディレクトリ。write(to:) はここで失敗する。
        let destination = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/cat.png")

        do {
            try image().save(to: destination)
            Issue.record("throw されるべき")
        } catch let error as GeneratedMediaError {
            guard case .saveError = error else {
                Issue.record("saveError であるべき: \(error)")
                return
            }
        } catch {
            Issue.record("GeneratedMediaError であるべき: \(error)")
        }
    }

    @Test("saveError は元のファイルシステムエラーを保つ")
    func saveErrorCarriesTheUnderlyingReason() {
        let destination = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/cat.png")

        do {
            try image().save(to: destination)
            Issue.record("throw されるべき")
        } catch let GeneratedMediaError.saveError(underlying) {
            #expect(underlying is CocoaError, "元のエラーが失われている: \(underlying)")
        } catch {
            Issue.record("saveError であるべき: \(error)")
        }
    }

    @Test("書き込める場所には今までどおり保存できる")
    func successfulSaveStillWorks() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: destination) }

        try image().save(to: destination)

        #expect(try Data(contentsOf: destination) == image().data)
    }
}

// MARK: - audioPlayer

#if canImport(AVFoundation)
@Suite("GeneratedAudio.audioPlayer は再生できない理由を渡す")
struct GeneratedAudioPlayerTests {
    /// ヘッダを持たない生 PCM。Gemini TTS が返すのはこれ。
    private func rawPCM() -> GeneratedAudio {
        GeneratedAudio(data: Data(repeating: 0x00, count: 512), format: .pcm)
    }

    /// 途中で切れた WAV。先頭は WAV だがデータチャンクが無い。
    private func truncatedWAV() -> GeneratedAudio {
        GeneratedAudio(data: Data("RIFF".utf8), format: .wav)
    }

    @Test("コンテナの無い PCM は AVFoundation 自身の理由で失敗する")
    func rawPCMFailsWithAVFoundationsOwnReason() {
        do {
            _ = try rawPCM().audioPlayer
            Issue.record("throw されるべき")
        } catch {
            // 差し替えた汎用エラーではなく、AVFoundation が挙げた理由そのものが届く。
            #expect((error as NSError).domain == NSOSStatusErrorDomain)
        }
    }

    @Test("途中で切れたバイト列も AVFoundation 自身の理由で失敗する")
    func truncatedBytesFailWithAVFoundationsOwnReason() {
        do {
            _ = try truncatedWAV().audioPlayer
            Issue.record("throw されるべき")
        } catch {
            #expect((error as NSError).domain == NSOSStatusErrorDomain)
        }
    }

    @Test("再生できるバイト列ではプレイヤーが返る")
    func playableBytesProduceAPlayer() throws {
        let player = try GeneratedAudio(data: silentWAV(), format: .wav).audioPlayer
        #expect(player.duration > 0)
    }

    /// 8 kHz・16bit・モノラルの無音を 0.1 秒ぶん。AVAudioPlayer が受け取れる最小の WAV。
    private func silentWAV() -> Data {
        let sampleRate = 8000
        let frames = sampleRate / 10
        let dataBytes = frames * 2

        var wav = Data()
        func append(_ string: String) { wav.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: Int) { wav.append(contentsOf: withUnsafeBytes(of: UInt32(value).littleEndian, Array.init)) }
        func append16(_ value: Int) { wav.append(contentsOf: withUnsafeBytes(of: UInt16(value).littleEndian, Array.init)) }

        append("RIFF")
        append32(36 + dataBytes)
        append("WAVE")
        append("fmt ")
        append32(16)            // PCM ヘッダ長
        append16(1)             // PCM
        append16(1)             // モノラル
        append32(sampleRate)
        append32(sampleRate * 2) // バイト毎秒
        append16(2)             // ブロックあたりのバイト数
        append16(16)            // ビット深度
        append("data")
        append32(dataBytes)
        wav.append(Data(repeating: 0, count: dataBytes))
        return wav
    }
}
#endif
