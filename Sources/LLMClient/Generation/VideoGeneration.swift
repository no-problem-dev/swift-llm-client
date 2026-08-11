// VideoGeneration.swift
// swift-llm-client
//
// Protocols and supporting types for video generation.

import Foundation

// MARK: - VideoGenerationCapable Protocol

/// A client that can generate video from a prompt.
///
/// Rendering takes minutes, so it runs as a job rather than a single request: start it, poll the
/// status until it settles, then fetch the video. The `generateVideo(input:model:...)` convenience
/// runs that loop for you.
///
/// ## Example
/// ```swift
/// // Start the render.
/// let job = try await client.startVideoGeneration(
///     input: "A cat playing with a ball in slow motion",
///     model: .sora2
/// )
///
/// // Poll until the job settles.
/// var currentJob = job
/// while !currentJob.status.isTerminal {
///     try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
///     currentJob = try await client.checkVideoStatus(currentJob)
/// }
///
/// // Fetch the video.
/// if currentJob.status.isSuccessful {
///     let video = try await client.getGeneratedVideo(currentJob)
///     try video.save(to: URL(fileURLWithPath: "output.mp4"))
/// }
/// ```
public protocol VideoGenerationCapable<VideoModel>: Sendable {
    /// The catalog of video models this client accepts.
    associatedtype VideoModel: Sendable

    /// Starts a render and returns straight away, without waiting for it.
    ///
    /// - Parameters:
    ///   - input: The prompt to render.
    ///   - model: The video model to call.
    ///   - duration: Clip length in seconds. Only the lengths in the model's supported list work.
    ///   - aspectRatio: Frame shape. Nil leaves the choice to the provider's default.
    ///   - resolution: Output resolution, which the model may cap.
    /// - Returns: A job to poll. No video is available yet.
    func startVideoGeneration(
        input: LLMInput,
        model: VideoModel,
        duration: Int?,
        aspectRatio: VideoAspectRatio?,
        resolution: VideoResolution?
    ) async throws -> VideoGenerationJob

    /// Polls the provider for a job's current status.
    ///
    /// - Parameter job: The job to poll.
    /// - Returns: A fresh snapshot. The value passed in is left untouched.
    func checkVideoStatus(_ job: VideoGenerationJob) async throws -> VideoGenerationJob

    /// Downloads the finished video.
    ///
    /// Only a job whose status is `completed` has a video to fetch. Asking earlier is the case
    /// `VideoGenerationError.jobNotCompleted` reports.
    ///
    /// - Parameter job: A job that has finished successfully.
    /// - Returns: The generated video.
    func getGeneratedVideo(_ job: VideoGenerationJob) async throws -> GeneratedVideo
}

// MARK: - Default Implementations

extension VideoGenerationCapable {
    /// Starts a render, filling in defaults for the duration, aspect ratio, and resolution.
    ///
    /// It exists only to supply those defaults and forwards to the conforming type's own
    /// implementation.
    public func startVideoGeneration(
        input: LLMInput,
        model: VideoModel,
        duration: Int? = nil,
        aspectRatio: VideoAspectRatio? = nil,
        resolution: VideoResolution? = nil
    ) async throws -> VideoGenerationJob {
        try await startVideoGeneration(
            input: input,
            model: model,
            duration: duration,
            aspectRatio: aspectRatio,
            resolution: resolution
        )
    }

    /// Starts a render and waits for it, polling until the job settles.
    ///
    /// Every settled outcome that is not a finished video throws: a failed render, a cancelled one,
    /// and the timeout elapsing. Giving up on the timeout only stops the polling — the render
    /// carries on at the provider.
    ///
    /// - Parameters:
    ///   - input: The prompt to render.
    ///   - model: The video model to call.
    ///   - duration: Clip length in seconds. Only the lengths in the model's supported list work.
    ///   - aspectRatio: Frame shape. Nil leaves the choice to the provider's default.
    ///   - resolution: Output resolution, which the model may cap.
    ///   - pollingInterval: Seconds to wait between status checks.
    ///   - timeout: Seconds to keep polling before throwing.
    /// - Returns: The generated video.
    public func generateVideo(
        input: LLMInput,
        model: VideoModel,
        duration: Int? = nil,
        aspectRatio: VideoAspectRatio? = nil,
        resolution: VideoResolution? = nil,
        pollingInterval: TimeInterval = 5,
        timeout: TimeInterval = 600
    ) async throws -> GeneratedVideo {
        var job = try await startVideoGeneration(
            input: input,
            model: model,
            duration: duration,
            aspectRatio: aspectRatio,
            resolution: resolution
        )

        let startTime = Date()

        while !job.status.isTerminal {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                throw VideoGenerationError.timeout(elapsed: elapsed)
            }

            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
            job = try await checkVideoStatus(job)
        }

        if job.status == .failed {
            throw VideoGenerationError.generationFailed(job.errorMessage ?? "Unknown error")
        }

        if job.status == .cancelled {
            throw VideoGenerationError.cancelled
        }

        return try await getGeneratedVideo(job)
    }
}

// MARK: - OpenAI Video Models

/// The OpenAI video generation models.
///
/// Sora 2 is OpenAI's second-generation video model, released in September 2025 and reachable
/// through the API.
public enum OpenAIVideoModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// Sora 2, the faster standard tier.
    ///
    /// Suited to prototypes and social media. It renders at 720p (1280x720) and nothing higher.
    case sora2 = "sora-2"

    /// Sora 2 Pro, the higher-quality tier.
    ///
    /// Suited to production and marketing work. It renders at 720p or 1080p (1792x1024) and
    /// defaults to 1080p.
    case sora2Pro = "sora-2-pro"

    /// The identifier sent to the API.
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sora2: return "Sora 2"
        case .sora2Pro: return "Sora 2 Pro"
        }
    }

    /// The clip lengths in seconds the model accepts. Nothing in between them works.
    public var supportedDurations: [Int] {
        [4, 8, 12]
    }

    /// The longest clip the model renders, in seconds.
    public var maxDuration: Int { 12 }

    /// The aspect ratios the model accepts, which are 16:9 and its portrait counterpart only.
    public var supportedAspectRatios: [VideoAspectRatio] {
        [.landscape16x9, .portrait9x16]
    }

    /// The resolutions the model accepts. 1080p is a Pro-only option.
    public var supportedResolutions: [VideoResolution] {
        switch self {
        case .sora2:
            return [.hd720p]
        case .sora2Pro:
            return [.hd720p, .fhd1080p]
        }
    }

    /// The resolution to fall back on when the caller names none.
    public var defaultResolution: VideoResolution {
        switch self {
        case .sora2: return .hd720p
        case .sora2Pro: return .fhd1080p
        }
    }
}

// MARK: - Gemini Video Models

/// The Gemini video generation models, the Veo family.
public enum GeminiVideoModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// Veo 3.1, the newest and highest quality, served from a preview endpoint.
    case veo31 = "veo-3.1-generate-preview"
    /// Veo 3.1 Fast, which trades quality for speed. Also a preview endpoint.
    case veo31Fast = "veo-3.1-fast-generate-preview"
    /// Veo 3.0, the stable release.
    case veo30 = "veo-3.0-generate-001"
    /// Veo 3.0 Fast, the faster stable variant.
    case veo30Fast = "veo-3.0-fast-generate-001"
    /// Veo 2.0, the previous generation. It renders at 720p only and has no four-second clip.
    case veo20 = "veo-2.0-generate-001"

    /// The identifier sent to the API.
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .veo31: return "Veo 3.1"
        case .veo31Fast: return "Veo 3.1 Fast"
        case .veo30: return "Veo 3.0"
        case .veo30Fast: return "Veo 3.0 Fast"
        case .veo20: return "Veo 2.0"
        }
    }

    /// The longest clip any Veo model renders, in seconds.
    public var maxDuration: Int { 8 }

    /// The clip lengths in seconds the model accepts. Nothing in between them works.
    public var supportedDurations: [Int] {
        switch self {
        case .veo31, .veo31Fast, .veo30, .veo30Fast:
            return [4, 6, 8]
        case .veo20:
            return [5, 6, 8]  // Veo 2.0 supports 5-8 seconds only.
        }
    }

    /// The aspect ratios the model accepts, which are 16:9 and its portrait counterpart only.
    public var supportedAspectRatios: [VideoAspectRatio] {
        [.landscape16x9, .portrait9x16]
    }

    /// The resolutions the model accepts. Veo 2.0 renders at 720p and nothing higher.
    public var supportedResolutions: [VideoResolution] {
        switch self {
        case .veo31, .veo31Fast, .veo30, .veo30Fast:
            return [.hd720p, .fhd1080p]  // 1080p only at 8 seconds.
        case .veo20:
            return [.hd720p]
        }
    }
}

// MARK: - VideoGenerationError

/// Failures specific to video generation, as opposed to transport or decoding errors.
public enum VideoGenerationError: Error, Sendable, LocalizedError {
    /// The prompt was refused by the provider's safety policy, with the reason it gave.
    case contentPolicyViolation(String?)
    /// A longer clip was asked for than the model renders.
    case durationExceedsLimit(requested: Int, maximum: Int)
    /// The requested aspect ratio is not one the model accepts.
    case unsupportedAspectRatio(VideoAspectRatio, model: String)
    /// The requested resolution is not one the model accepts.
    case unsupportedResolution(VideoResolution, model: String)
    /// The provider reported the render as failed, with the message it gave.
    case generationFailed(String)
    /// Polling gave up before the job settled. The render carries on at the provider.
    case timeout(elapsed: TimeInterval)
    /// The job stopped before finishing, either by request or by the provider.
    case cancelled
    /// The video was asked for while the job was still unfinished.
    case jobNotCompleted(status: VideoGenerationStatus)
    /// The provider generates no video at all.
    case notSupportedByProvider(String)

    public var errorDescription: String? {
        switch self {
        case .contentPolicyViolation(let reason):
            return "Content policy violation\(reason.map { ": \($0)" } ?? "")"
        case .durationExceedsLimit(let requested, let maximum):
            return "Requested duration (\(requested)s) exceeds maximum (\(maximum)s)"
        case .unsupportedAspectRatio(let ratio, let model):
            return "Aspect ratio \(ratio.rawValue) is not supported by \(model)"
        case .unsupportedResolution(let resolution, let model):
            return "Resolution \(resolution.rawValue) is not supported by \(model)"
        case .generationFailed(let message):
            return "Video generation failed: \(message)"
        case .timeout(let elapsed):
            return "Video generation timed out after \(Int(elapsed)) seconds"
        case .cancelled:
            return "Video generation was cancelled"
        case .jobNotCompleted(let status):
            return "Video job is not completed (status: \(status.rawValue))"
        case .notSupportedByProvider(let provider):
            return "Video generation is not supported by \(provider)"
        }
    }
}
