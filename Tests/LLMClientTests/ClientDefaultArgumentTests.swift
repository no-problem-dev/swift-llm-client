import Foundation
import Testing
@testable import LLMClient

// MARK: - 背景
//
// 既定引数を与えるためのプロトコル拡張が、要件とまったく同じシグネチャを持っていた。
// そのため要件を実装し忘れた準拠型がコンパイルを通り、呼ぶと拡張が自分自身を呼び続けて
// 無限再帰した（throwaway パッケージで再現: 10 秒で RSS 約 987MB）。
//
// 修正は要件側を `options:` 一本にして、既定引数を持つ利便メソッドと
// シグネチャを分けたこと。これにより
//   1. 要件を実装しない準拠型はコンパイルエラーになる（本ファイルのモックが実装を落とすと落ちる）
//   2. 利便メソッドは必ず要件へ 1 回だけ委譲する（以下のテストが値の到達を検証する）

// MARK: - Fixtures

private struct Echo: StructuredProtocol, Equatable {
    var text: String
    static var jsonSchema: JSONSchema {
        JSONSchema(type: .object, properties: ["text": JSONSchema(type: .string)], required: ["text"])
    }
}

/// 呼び出し回数と到達したオプションを記録する。無限再帰なら `calls` が 1 で止まらない。
private final class CallRecorder<Options: Sendable>: @unchecked Sendable {
    private(set) var calls = 0
    private(set) var last: Options?
    func record(_ options: Options) {
        calls += 1
        last = options
    }
}

/// `StructuredLLMClient` の要件だけを実装する。既定引数版は一切実装しない。
private struct RecordingStructuredClient: StructuredLLMClient {
    typealias Model = String

    let inputCalls = CallRecorder<GenerationOptions>()
    let messageCalls = CallRecorder<GenerationOptions>()

    func generateWithUsage<T: StructuredProtocol>(
        input: LLMInput,
        model: Model,
        options: GenerationOptions
    ) async throws -> GenerationResult<T> {
        inputCalls.record(options)
        return try Self.makeResult(model: model)
    }

    func generateWithUsage<T: StructuredProtocol>(
        messages: [LLMMessage],
        model: Model,
        options: GenerationOptions
    ) async throws -> GenerationResult<T> {
        messageCalls.record(options)
        return try Self.makeResult(model: model)
    }

    private static func makeResult<T: StructuredProtocol>(model: String) throws -> GenerationResult<T> {
        let json = #"{"text":"ok"}"#
        return GenerationResult(
            result: try JSONDecoder().decode(T.self, from: Data(json.utf8)),
            usage: TokenUsage(inputTokens: 1, outputTokens: 1),
            model: model,
            rawText: json,
            stopReason: .endTurn
        )
    }
}

/// `ImageGenerationCapable` の要件だけを実装する。
private struct RecordingImageClient: ImageGenerationCapable {
    typealias ImageModel = String

    let singleCalls = CallRecorder<ImageGenerationOptions>()
    let batchCalls = CallRecorder<ImageGenerationOptions>()

    func generateImage(
        input: LLMInput,
        model: ImageModel,
        options: ImageGenerationOptions
    ) async throws -> GeneratedImage {
        singleCalls.record(options)
        return GeneratedImage(data: Data([0x1]), format: .png)
    }

    func generateImages(
        input: LLMInput,
        model: ImageModel,
        options: ImageGenerationOptions
    ) async throws -> [GeneratedImage] {
        batchCalls.record(options)
        return [GeneratedImage(data: Data([0x1]), format: .png)]
    }
}

/// `SpeechGenerationCapable` の要件だけを実装する。
private struct RecordingSpeechClient: SpeechGenerationCapable {
    typealias SpeechModel = String
    typealias Voice = String

    let calls = CallRecorder<SpeechGenerationOptions>()

    func generateSpeech(
        input: LLMInput,
        model: SpeechModel,
        voice: Voice,
        options: SpeechGenerationOptions
    ) async throws -> GeneratedAudio {
        calls.record(options)
        return GeneratedAudio(data: Data([0x1]), format: .mp3)
    }
}

/// `VideoGenerationCapable` の要件だけを実装する。
private struct RecordingVideoClient: VideoGenerationCapable {
    typealias VideoModel = String

    let calls = CallRecorder<VideoGenerationOptions>()

    func startVideoGeneration(
        input: LLMInput,
        model: VideoModel,
        options: VideoGenerationOptions
    ) async throws -> VideoGenerationJob {
        calls.record(options)
        return VideoGenerationJob(id: "job-1", status: .completed, prompt: "p")
    }

    func checkVideoStatus(_ job: VideoGenerationJob) async throws -> VideoGenerationJob { job }

    func getGeneratedVideo(_ job: VideoGenerationJob) async throws -> GeneratedVideo {
        GeneratedVideo(data: Data([0x1]))
    }
}

// MARK: - Tests

@Suite("既定引数の利便メソッドは要件へ 1 回だけ委譲する")
struct ClientDefaultArgumentTests {

    @Test("generateWithUsage(input:) は再帰せず 1 回で要件へ届く")
    func inputFormForwardsOnce() async throws {
        let client = RecordingStructuredClient()
        let _: GenerationResult<Echo> = try await client.generateWithUsage(input: "hi", model: "m")
        #expect(client.inputCalls.calls == 1)
        #expect(client.inputCalls.last == GenerationOptions())
    }

    @Test("generateWithUsage(input:) は与えた引数を options へ詰めて渡す")
    func inputFormCarriesArguments() async throws {
        let client = RecordingStructuredClient()
        let _: GenerationResult<Echo> = try await client.generateWithUsage(
            input: "hi",
            model: "m",
            systemPrompt: "sys",
            temperature: 0.25,
            maxTokens: 512
        )
        #expect(client.inputCalls.calls == 1)
        #expect(client.inputCalls.last?.systemPrompt == SystemPrompt(stringLiteral: "sys"))
        #expect(client.inputCalls.last?.temperature == 0.25)
        #expect(client.inputCalls.last?.maxTokens == 512)
    }

    @Test("generateWithUsage(messages:) も同じく 1 回で届く")
    func messagesFormForwardsOnce() async throws {
        let client = RecordingStructuredClient()
        let _: GenerationResult<Echo> = try await client.generateWithUsage(
            messages: [.user("hi")],
            model: "m",
            maxTokens: 64
        )
        #expect(client.messageCalls.calls == 1)
        #expect(client.messageCalls.last?.maxTokens == 64)
    }

    @Test("generate は generateWithUsage の要件へ 1 回だけ降りる")
    func generateForwardsOnce() async throws {
        let client = RecordingStructuredClient()
        let value: Echo = try await client.generate(input: "hi", model: "m", temperature: 1)
        #expect(value == Echo(text: "ok"))
        #expect(client.inputCalls.calls == 1)
        #expect(client.inputCalls.last?.temperature == 1)
    }

    @Test("ジェネリック文脈から呼んでも要件へ 1 回だけ届く")
    func forwardsOnceThroughGenericContext() async throws {
        func call<C: StructuredLLMClient>(_ client: C, model: C.Model) async throws -> Echo {
            try await client.generate(input: "hi", model: model, maxTokens: 8)
        }
        let client = RecordingStructuredClient()
        _ = try await call(client, model: "m")
        #expect(client.inputCalls.calls == 1)
        #expect(client.inputCalls.last?.maxTokens == 8)
    }

    @Test("generateImage / generateImages の既定引数版が再帰しない")
    func imageFormsForwardOnce() async throws {
        let client = RecordingImageClient()
        _ = try await client.generateImage(input: "cat", model: "m", size: .square1024)
        _ = try await client.generateImages(input: "cat", model: "m", n: 3)
        #expect(client.singleCalls.calls == 1)
        #expect(client.singleCalls.last?.size == .square1024)
        #expect(client.singleCalls.last?.n == 1)
        #expect(client.batchCalls.calls == 1)
        #expect(client.batchCalls.last?.n == 3)
    }

    @Test("generateSpeech の既定引数版が再帰しない")
    func speechFormForwardsOnce() async throws {
        let client = RecordingSpeechClient()
        _ = try await client.generateSpeech(input: "hello", model: "m", voice: "alloy", speed: 1.5)
        #expect(client.calls.calls == 1)
        #expect(client.calls.last?.speed == 1.5)
        #expect(client.calls.last?.format == nil)
    }

    @Test("startVideoGeneration の既定引数版が再帰しない")
    func videoFormForwardsOnce() async throws {
        let client = RecordingVideoClient()
        _ = try await client.startVideoGeneration(input: "cat", model: "m", duration: 5)
        #expect(client.calls.calls == 1)
        #expect(client.calls.last?.duration == 5)
        #expect(client.calls.last?.resolution == nil)
    }

    @Test("generateVideo のポーリング版も startVideoGeneration へ 1 回だけ降りる")
    func generateVideoForwardsOnce() async throws {
        let client = RecordingVideoClient()
        _ = try await client.generateVideo(input: "cat", model: "m", resolution: .hd720p)
        #expect(client.calls.calls == 1)
        #expect(client.calls.last?.resolution == .hd720p)
    }
}
