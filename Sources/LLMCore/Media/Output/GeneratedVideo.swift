// GeneratedVideo.swift
// swift-llm-client
//
// Video content produced by a model, and the job that produces it.

import Foundation

// MARK: - VideoGenerationStatus

/// Where a video generation job stands.
///
/// Video generation runs far too long for one request, so providers hand back a job and the client
/// polls this until it settles.
public enum VideoGenerationStatus: String, Sendable, Codable, Equatable {
    /// Accepted by the provider but not started; no work is being billed yet.
    case queued

    /// Rendering. This is the state a poll loop waits out, typically for minutes.
    case processing

    /// Finished successfully; the video is ready to fetch.
    case completed

    /// Rendering stopped with an error, which the job carries as a message.
    case failed

    /// Stopped before completion, either by request or by the provider.
    case cancelled

    /// Whether the job has settled and will not change again, however it ended.
    ///
    /// This is the condition to poll on: it covers failure and cancellation as well as success, so
    /// a loop keyed to it cannot spin forever on a job that will never complete.
    public var isTerminal: Bool {
        switch self {
        case .queued, .processing:
            return false
        case .completed, .failed, .cancelled:
            return true
        }
    }

    /// Whether the job ended in a usable video, as opposed to any other settled outcome.
    public var isSuccessful: Bool {
        self == .completed
    }
}

// MARK: - VideoGenerationJob

/// A long-running video generation request and everything known about it so far.
///
/// Rendering takes minutes, so the provider returns this immediately and the client polls for the
/// status before fetching the video. Both OpenAI Sora and Gemini Veo work this way.
///
/// The value is a snapshot: polling returns a new job rather than mutating this one.
///
/// ## Example
/// ```swift
/// var job = try await client.startVideoGeneration(
///     input: "A cat playing with a ball",
///     model: .sora2
/// )
///
/// while !job.status.isTerminal {
///     try await Task.sleep(nanoseconds: 5_000_000_000)
///     job = try await client.checkVideoStatus(job)
/// }
///
/// let video = try await client.getGeneratedVideo(job)
/// try video.save(to: URL(fileURLWithPath: "output.mp4"))
/// ```
///
/// The convenience overload `generateVideo(input:model:...)` runs that loop for you, with its own
/// polling interval and timeout.
public struct VideoGenerationJob: Sendable, Codable, Equatable, Identifiable {
    // MARK: - Properties

    /// The provider's handle for the job, and the only thing needed to poll it.
    public let id: String

    /// How far the job has got, as of the last poll.
    public var status: VideoGenerationStatus

    /// The prompt the job was started with, kept so a result can be traced back to its request.
    public let prompt: String

    /// The duration, resolution, frame rate, and aspect ratio the job was started with.
    public let configuration: VideoGenerationConfiguration?

    /// When the job was created locally.
    ///
    /// It is set by this client, not read from the provider, and is what elapsed time is measured
    /// against.
    public let createdAt: Date

    /// When the job was last polled. Nil until the first status update.
    public var updatedAt: Date?

    /// When the job settled, whether it succeeded, failed, or was cancelled.
    public var completedAt: Date?

    /// Where the finished video lives on the provider's servers.
    ///
    /// Set only once the job completes. These URLs are usually short-lived, so download the bytes
    /// rather than storing the link.
    public var videoURL: URL?

    /// What went wrong, when the job failed.
    public var errorMessage: String?

    /// How far along the render is, from 0 to 1, for providers that report it.
    ///
    /// Nil when the provider gives no progress signal, which is the common case; treat its absence
    /// as no information rather than as no progress.
    public var progress: Double?

    // MARK: - Initializers

    /// Creates a job snapshot, normally from the response that started the render.
    ///
    /// - Parameters:
    ///   - id: The provider's handle for the job.
    ///   - status: Where the job stands; a freshly accepted job is queued.
    ///   - prompt: The prompt the job was started with.
    ///   - configuration: The settings the job was started with.
    ///   - createdAt: The local start time that elapsed time is measured against.
    public init(
        id: String,
        status: VideoGenerationStatus = .queued,
        prompt: String,
        configuration: VideoGenerationConfiguration? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.prompt = prompt
        self.configuration = configuration
        self.createdAt = createdAt
    }

    // MARK: - Status Updates

    /// Returns a copy of the job carrying a newer status.
    ///
    /// Omitted arguments keep the value already on the job rather than clearing it, so a poll that
    /// reports only a status does not erase a URL or progress figure seen earlier. Nil is therefore
    /// not a way to unset a field. The update stamps the poll time, and stamps the completion time
    /// as well once the new status is settled.
    ///
    /// - Parameters:
    ///   - status: The status just observed.
    ///   - videoURL: Where the finished video lives, once the provider reports it.
    ///   - errorMessage: What went wrong, when the job failed.
    ///   - progress: How far along the render is, from 0 to 1.
    public func updated(
        status: VideoGenerationStatus,
        videoURL: URL? = nil,
        errorMessage: String? = nil,
        progress: Double? = nil
    ) -> VideoGenerationJob {
        var job = self
        job.status = status
        job.updatedAt = Date()
        job.videoURL = videoURL ?? self.videoURL
        job.errorMessage = errorMessage ?? self.errorMessage
        job.progress = progress ?? self.progress
        if status == .completed || status == .failed || status == .cancelled {
            job.completedAt = Date()
        }
        return job
    }

    // MARK: - Convenience

    /// Seconds the job has been running, or ran for in total once it settled.
    ///
    /// While the job is in flight this keeps climbing with the clock, so reading it twice gives
    /// two different answers. Use it to drive a timeout.
    public var elapsedTime: TimeInterval {
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(createdAt)
    }

    /// Seconds left, projected from elapsed time and reported progress.
    ///
    /// Nil unless the provider reports progress strictly between 0 and 1, which rules out both a
    /// job that has not started moving and one that is already done. The projection assumes the
    /// render proceeds at a constant rate, so it is a display hint, not a schedule.
    public var estimatedRemainingTime: TimeInterval? {
        guard let progress = progress, progress > 0, progress < 1 else {
            return nil
        }
        let elapsed = elapsedTime
        let totalEstimated = elapsed / progress
        return totalEstimated - elapsed
    }
}

// MARK: - VideoGenerationConfiguration

/// What to render, and how, when starting a video generation job.
///
/// Every setting except the container format is optional; leaving one out defers to the provider's
/// own default, and providers accept only a narrow set of values for each. Longer clips and higher
/// resolutions cost proportionally more and take proportionally longer to render.
public struct VideoGenerationConfiguration: Sendable, Codable, Equatable {
    /// Length of the clip in whole seconds. Providers cap this tightly, often at a handful.
    public let duration: Int?

    /// Frame size to render at.
    public let resolution: VideoResolution?

    /// Frames per second to render at.
    public let frameRate: Int?

    /// Shape of the frame, which providers may honor in place of an explicit resolution.
    public let aspectRatio: VideoAspectRatio?

    /// Container to deliver the video in. MP4 is the only format any provider currently returns.
    public let format: VideoOutputFormat

    /// Creates a configuration, leaving anything unspecified to the provider's default.
    ///
    /// - Parameters:
    ///   - duration: Length of the clip in whole seconds.
    ///   - resolution: Frame size to render at.
    ///   - frameRate: Frames per second to render at.
    ///   - aspectRatio: Shape of the frame.
    ///   - format: Container to deliver the video in.
    public init(
        duration: Int? = nil,
        resolution: VideoResolution? = nil,
        frameRate: Int? = nil,
        aspectRatio: VideoAspectRatio? = nil,
        format: VideoOutputFormat = .mp4
    ) {
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.aspectRatio = aspectRatio
        self.format = format
    }
}

// MARK: - VideoResolution

/// A frame size to render video at.
///
/// The raw values are the shorthand names providers use on the wire. Not every provider or model
/// accepts every size, and the larger ones cost more.
public enum VideoResolution: String, Sendable, Codable, CaseIterable, Equatable {
    /// 480p (854x480)
    case sd480p = "480p"

    /// 720p (1280x720)
    case hd720p = "720p"

    /// 1080p (1920x1080)
    case fhd1080p = "1080p"

    /// 4K (3840x2160)
    case uhd4k = "4k"

    /// Frame width in pixels, assuming a landscape frame.
    public var width: Int {
        switch self {
        case .sd480p: return 854
        case .hd720p: return 1280
        case .fhd1080p: return 1920
        case .uhd4k: return 3840
        }
    }

    /// Frame height in pixels, assuming a landscape frame.
    public var height: Int {
        switch self {
        case .sd480p: return 480
        case .hd720p: return 720
        case .fhd1080p: return 1080
        case .uhd4k: return 2160
        }
    }
}

// MARK: - VideoAspectRatio

/// The shape of a video frame.
///
/// The raw values are the ratio strings providers expect on the wire. Support varies by model;
/// widescreen and vertical are the two most widely accepted.
public enum VideoAspectRatio: String, Sendable, Codable, CaseIterable, Equatable {
    /// 16:9 widescreen, the usual landscape shape.
    case landscape16x9 = "16:9"

    /// 9:16 vertical, for phone-first playback.
    case portrait9x16 = "9:16"

    /// 1:1 square.
    case square1x1 = "1:1"

    /// 4:3, the older standard shape.
    case standard4x3 = "4:3"

    /// 21:9 cinemascope.
    case cinematic21x9 = "21:9"

    /// The width term of the ratio.
    public var widthRatio: Int {
        switch self {
        case .landscape16x9: return 16
        case .portrait9x16: return 9
        case .square1x1: return 1
        case .standard4x3: return 4
        case .cinematic21x9: return 21
        }
    }

    /// The height term of the ratio.
    public var heightRatio: Int {
        switch self {
        case .landscape16x9: return 9
        case .portrait9x16: return 16
        case .square1x1: return 1
        case .standard4x3: return 3
        case .cinematic21x9: return 9
        }
    }

    /// Whether the frame is wider than it is tall. A square frame is neither landscape nor portrait.
    public var isLandscape: Bool {
        widthRatio > heightRatio
    }

    /// Whether the frame is taller than it is wide. A square frame is neither portrait nor landscape.
    public var isPortrait: Bool {
        heightRatio > widthRatio
    }
}

// MARK: - GeneratedVideo

/// A finished video, held either as bytes or as a link to the provider's copy.
///
/// Fetched once a generation job completes. Unlike generated images and audio, this may carry no
/// bytes at all — a value built from a URL alone has empty data until it is downloaded, and saving
/// it in that state writes a zero-length file. Provider-hosted URLs are short-lived, so download
/// the bytes rather than persisting the link; `downloadData(using:)` throws rather than handing
/// back an empty video when there is nothing to fetch.
///
/// ## Example
/// ```swift
/// let video = try await client.getGeneratedVideo(job)
///
/// // Empty unless the bytes were downloaded.
/// if video.hasLocalData {
///     try video.save(to: URL(fileURLWithPath: "output.mp4"))
/// }
///
/// // Streaming straight from the provider, while the URL is still valid.
/// if let url = video.remoteURL {
///     let player = AVPlayer(url: url)
///     player.play()
/// }
/// ```
public struct GeneratedVideo: GeneratedMediaProtocol {
    // MARK: - Properties

    /// The video bytes, or empty data when only the remote URL is known.
    ///
    /// Check whether local data is present before saving; downloading fills this in on a copy.
    public let data: Data

    /// The container of the video, which fixes both the MIME type and the file extension.
    public let format: VideoOutputFormat

    /// Where the video lives on the provider's servers.
    ///
    /// Playable directly by a streaming player, and the source for downloading the bytes. These
    /// links expire, so treat the URL as usable now rather than storable.
    public let remoteURL: URL?

    /// Length of the clip in seconds, when the provider reports it.
    ///
    /// Copied from the response and never measured from the bytes.
    public let duration: TimeInterval?

    /// Frame size the video was rendered at, when the provider reports it.
    public let resolution: VideoResolution?

    /// The generation job this video came out of, kept so a file can be traced back to its render.
    public let jobId: String?

    /// The prompt the video was rendered from.
    public let prompt: String?

    // MARK: - GeneratedMediaProtocol

    /// The MIME type of the video, taken from the format.
    public var mimeType: String { format.mimeType }

    /// The file extension for the video, taken from the format.
    public var fileExtension: String { format.fileExtension }

    // MARK: - Initializers

    /// Creates a video that already holds its bytes.
    ///
    /// - Parameters:
    ///   - data: The video bytes.
    ///   - format: Container of the bytes. It is taken on trust and never verified against them.
    ///   - remoteURL: Where the provider's copy lives, if it is still hosted.
    ///   - duration: Length of the clip in seconds.
    ///   - resolution: Frame size the video was rendered at.
    ///   - jobId: The generation job this video came out of.
    ///   - prompt: The prompt the video was rendered from.
    public init(
        data: Data,
        format: VideoOutputFormat = .mp4,
        remoteURL: URL? = nil,
        duration: TimeInterval? = nil,
        resolution: VideoResolution? = nil,
        jobId: String? = nil,
        prompt: String? = nil
    ) {
        self.data = data
        self.format = format
        self.remoteURL = remoteURL
        self.duration = duration
        self.resolution = resolution
        self.jobId = jobId
        self.prompt = prompt
    }

    /// Creates a video that only points at the provider's copy.
    ///
    /// The data is left empty and no request is made here, so the value cannot be saved to a usable
    /// file until the bytes are downloaded.
    ///
    /// - Parameters:
    ///   - remoteURL: Where the provider's copy lives.
    ///   - format: Container the provider will serve.
    ///   - duration: Length of the clip in seconds.
    ///   - resolution: Frame size the video was rendered at.
    ///   - jobId: The generation job this video came out of.
    ///   - prompt: The prompt the video was rendered from.
    public init(
        remoteURL: URL,
        format: VideoOutputFormat = .mp4,
        duration: TimeInterval? = nil,
        resolution: VideoResolution? = nil,
        jobId: String? = nil,
        prompt: String? = nil
    ) {
        self.data = Data()
        self.format = format
        self.remoteURL = remoteURL
        self.duration = duration
        self.resolution = resolution
        self.jobId = jobId
        self.prompt = prompt
    }

    // MARK: - Data Access

    /// Size of the held bytes, which is zero for a video known only by its URL.
    public var dataSize: Int {
        data.count
    }

    /// Whether the bytes are in hand, as opposed to still sitting behind the remote URL.
    ///
    /// Check this before saving: a video without local data writes an empty file.
    public var hasLocalData: Bool {
        !data.isEmpty
    }
}

// MARK: - Codable

extension GeneratedVideo {
    private enum CodingKeys: String, CodingKey {
        case data
        case format
        case remoteURL
        case duration
        case resolution
        case jobId
        case prompt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(Data.self, forKey: .data)
        self.format = try container.decode(VideoOutputFormat.self, forKey: .format)
        self.remoteURL = try container.decodeIfPresent(URL.self, forKey: .remoteURL)
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.resolution = try container.decodeIfPresent(VideoResolution.self, forKey: .resolution)
        self.jobId = try container.decodeIfPresent(String.self, forKey: .jobId)
        self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(format, forKey: .format)
        try container.encodeIfPresent(remoteURL, forKey: .remoteURL)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(resolution, forKey: .resolution)
        try container.encodeIfPresent(jobId, forKey: .jobId)
        try container.encodeIfPresent(prompt, forKey: .prompt)
    }
}
