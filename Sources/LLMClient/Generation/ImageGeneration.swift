// ImageGeneration.swift
// swift-llm-client
//
// Protocols and supporting types for image generation.

import Foundation

// MARK: - ImageGenerationCapable Protocol

/// A client that can generate images from a prompt.
///
/// The bytes travel with the result, so nothing here names a hosted asset that expires. Sizes,
/// formats, and how many images a single call may produce all vary by model — read the model's own
/// `supportedSizes` and `maxImages` first, because the provider rejects anything outside them.
///
/// ## Example
/// ```swift
/// // Generating an image with the OpenAI client.
/// let client = OpenAIClient(apiKey: "sk-...")
/// let image = try await client.generateImage(
///     input: "A cat sitting on a windowsill at sunset",
///     model: .gptImage,
///     size: .square1024
/// )
/// try image.save(to: URL(fileURLWithPath: "cat.png"))
/// ```
public protocol ImageGenerationCapable<ImageModel>: Sendable {
    /// The catalog of image models this client accepts.
    associatedtype ImageModel: Sendable

    /// Generates a single image.
    ///
    /// - Parameters:
    ///   - input: The prompt to render.
    ///   - model: The image model to call.
    ///   - size: Output size. Nil leaves the choice to the provider's default.
    ///   - quality: Rendering quality, for the models that offer the choice.
    ///   - format: Encoding of the returned bytes.
    ///   - n: How many images to ask the provider for.
    /// - Returns: The generated image.
    /// - Throws: `LLMError` or `ImageGenerationError`.
    func generateImage(
        input: LLMInput,
        model: ImageModel,
        size: ImageSize?,
        quality: ImageQuality?,
        format: ImageOutputFormat?,
        n: Int
    ) async throws -> GeneratedImage

    /// Generates a batch of images in one call.
    ///
    /// - Parameters:
    ///   - input: The prompt to render.
    ///   - model: The image model to call.
    ///   - size: Output size. Nil leaves the choice to the provider's default.
    ///   - quality: Rendering quality, for the models that offer the choice.
    ///   - format: Encoding of the returned bytes.
    ///   - n: How many images to generate. It must not exceed the model's maximum.
    /// - Returns: The generated images, in the order the provider returned them.
    func generateImages(
        input: LLMInput,
        model: ImageModel,
        size: ImageSize?,
        quality: ImageQuality?,
        format: ImageOutputFormat?,
        n: Int
    ) async throws -> [GeneratedImage]
}

// MARK: - Default Implementations

extension ImageGenerationCapable {
    /// Generates a single image, filling in defaults for everything but the prompt and the model.
    ///
    /// It exists only to supply those defaults and forwards to the conforming type's own
    /// implementation.
    public func generateImage(
        input: LLMInput,
        model: ImageModel,
        size: ImageSize? = nil,
        quality: ImageQuality? = nil,
        format: ImageOutputFormat? = nil,
        n: Int = 1
    ) async throws -> GeneratedImage {
        try await generateImage(
            input: input,
            model: model,
            size: size,
            quality: quality,
            format: format,
            n: n
        )
    }

    /// Generates a batch of images, filling in defaults for everything but the prompt and the model.
    ///
    /// It exists only to supply those defaults and forwards to the conforming type's own
    /// implementation.
    public func generateImages(
        input: LLMInput,
        model: ImageModel,
        size: ImageSize? = nil,
        quality: ImageQuality? = nil,
        format: ImageOutputFormat? = nil,
        n: Int = 1
    ) async throws -> [GeneratedImage] {
        try await generateImages(
            input: input,
            model: model,
            size: size,
            quality: quality,
            format: format,
            n: n
        )
    }
}

// MARK: - ImageSize

/// A pixel size for a generated image.
///
/// No model accepts every case. The per-model lists live on each model's `supportedSizes`, and
/// asking for a size outside them gets the request rejected.
public enum ImageSize: String, Sendable, Codable, CaseIterable, Equatable {
    // MARK: - Square Sizes

    /// 256x256 pixels. Accepted by DALL-E 2 and GPT-Image only.
    case square256 = "256x256"

    /// 512x512 pixels. Accepted by DALL-E 2 and GPT-Image only.
    case square512 = "512x512"

    /// 1024x1024 pixels, the one size every image model in this file accepts.
    case square1024 = "1024x1024"

    // MARK: - Landscape Sizes

    /// 1792x1024 pixels, landscape. Accepted by DALL-E 3 only.
    case landscape1792x1024 = "1792x1024"

    /// 1536x1024 pixels, landscape. Accepted by GPT-Image and the Imagen models.
    case landscape1536x1024 = "1536x1024"

    // MARK: - Portrait Sizes

    /// 1024x1792 pixels, portrait. Accepted by DALL-E 3 only.
    case portrait1024x1792 = "1024x1792"

    /// 1024x1536 pixels, portrait. Accepted by GPT-Image and the Imagen models.
    case portrait1024x1536 = "1024x1536"

    // MARK: - Properties

    /// The width in pixels.
    public var width: Int {
        switch self {
        case .square256: return 256
        case .square512: return 512
        case .square1024: return 1024
        case .landscape1792x1024: return 1792
        case .landscape1536x1024: return 1536
        case .portrait1024x1792: return 1024
        case .portrait1024x1536: return 1024
        }
    }

    /// The height in pixels.
    public var height: Int {
        switch self {
        case .square256: return 256
        case .square512: return 512
        case .square1024: return 1024
        case .landscape1792x1024: return 1024
        case .landscape1536x1024: return 1024
        case .portrait1024x1792: return 1792
        case .portrait1024x1536: return 1536
        }
    }

    public var isSquare: Bool { width == height }

    public var isLandscape: Bool { width > height }

    public var isPortrait: Bool { height > width }

    // MARK: - Provider Compatibility

    /// The three sizes DALL-E 3 accepts: one square, one landscape, one portrait.
    public static var dalle3Sizes: [ImageSize] {
        [.square1024, .landscape1792x1024, .portrait1024x1792]
    }

    /// The five sizes GPT-Image accepts, including the two small squares carried over from DALL-E 2.
    public static var gptImageSizes: [ImageSize] {
        [.square1024, .landscape1536x1024, .portrait1024x1536, .square256, .square512]
    }

    /// The three sizes the Imagen models accept.
    ///
    /// Despite the name, Imagen 3 and Imagen 4 share this list, and the Imagen 4 cases return it.
    public static var imagen3Sizes: [ImageSize] {
        [.square1024, .landscape1536x1024, .portrait1024x1536]
    }
}

// MARK: - ImageQuality

/// How much rendering effort to ask a model for.
public enum ImageQuality: String, Sendable, Codable, CaseIterable, Equatable {
    /// Standard quality, and the faster of the two.
    case standard
    /// High definition, at the cost of speed.
    case hd
}

// MARK: - ImageStyle

/// A rendering style, accepted by DALL-E 3 alone.
public enum ImageStyle: String, Sendable, Codable, CaseIterable, Equatable {
    /// A photorealistic look.
    case vivid
    /// A more natural, less stylized look.
    case natural
}

// MARK: - OpenAI Image Models

/// The OpenAI image generation models.
public enum OpenAIImageModel: String, Sendable, Codable, CaseIterable, Equatable {
    /// DALL-E 3. The higher-quality choice, but one image per request.
    case dalle3 = "dall-e-3"
    /// DALL-E 2, the previous generation. Up to ten images per request, all of them square.
    case dalle2 = "dall-e-2"
    /// GPT-Image, built on GPT-4o. Up to four images per request.
    case gptImage = "gpt-image-1"

    /// The identifier sent to the API.
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dalle3: return "DALL-E 3"
        case .dalle2: return "DALL-E 2"
        case .gptImage: return "GPT-Image"
        }
    }

    /// The sizes this model accepts. Any other size gets the request rejected.
    public var supportedSizes: [ImageSize] {
        switch self {
        case .dalle3: return ImageSize.dalle3Sizes
        case .dalle2: return [.square256, .square512, .square1024]
        case .gptImage: return ImageSize.gptImageSizes
        }
    }

    /// The most images one request may produce.
    public var maxImages: Int {
        switch self {
        case .dalle3: return 1
        case .dalle2: return 10
        case .gptImage: return 4
        }
    }
}

// MARK: - Gemini Image Models

/// The Gemini image generation models.
///
/// Imagen 3 is absent because the Gemini API (generativelanguage.googleapis.com) does not serve it
/// — it is reachable through Vertex AI only. That leaves the Imagen 4 models and the multimodal
/// Gemini Image model.
public enum GeminiImageModel: String, Sendable, Codable, CaseIterable, Equatable {
    // MARK: - Imagen 4 Models
    /// Imagen 4, the current generation.
    case imagen4 = "imagen-4.0-generate-001"
    /// Imagen 4 Ultra, the highest quality of the three.
    case imagen4Ultra = "imagen-4.0-ultra-generate-001"
    /// Imagen 4 Fast, which trades quality for speed.
    case imagen4Fast = "imagen-4.0-fast-generate-001"

    // MARK: - Gemini Image Models (multimodal generation)
    /// Gemini 2.0 Flash Image. Fast and cheap, but fixed at 1024x1024 and one image at a time.
    case gemini20FlashImage = "gemini-2.0-flash-exp-image-generation"

    /// The identifier sent to the API.
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .imagen4: return "Imagen 4"
        case .imagen4Ultra: return "Imagen 4 Ultra"
        case .imagen4Fast: return "Imagen 4 Fast"
        case .gemini20FlashImage: return "Gemini 2.0 Flash Image"
        }
    }

    /// Whether this is one of the Imagen models rather than the multimodal Gemini Image model.
    public var isImagenModel: Bool {
        switch self {
        case .imagen4, .imagen4Ultra, .imagen4Fast:
            return true
        case .gemini20FlashImage:
            return false
        }
    }

    /// The sizes this model accepts. Any other size gets the request rejected.
    public var supportedSizes: [ImageSize] {
        switch self {
        case .imagen4, .imagen4Ultra, .imagen4Fast:
            return ImageSize.imagen3Sizes
        case .gemini20FlashImage:
            // The Gemini Image model renders at a fixed size.
            return [.square1024]
        }
    }

    /// The most images one request may produce.
    public var maxImages: Int {
        switch self {
        case .imagen4, .imagen4Ultra, .imagen4Fast:
            return 4
        case .gemini20FlashImage:
            return 1  // Gemini Image returns one image at a time.
        }
    }
}

// MARK: - ImageGenerationError

/// Failures specific to image generation, as opposed to transport or decoding errors.
public enum ImageGenerationError: Error, Sendable, LocalizedError {
    /// The prompt was refused by the provider's safety policy, with the reason it gave.
    case contentPolicyViolation(String?)
    /// The requested size is not one the model accepts.
    case unsupportedSize(ImageSize, model: String)
    /// The requested output encoding is not one the model returns.
    case unsupportedFormat(ImageOutputFormat, model: String)
    /// More images were asked for than the model produces in a single call.
    case exceedsMaxImages(requested: Int, maximum: Int)
    /// The provider generates no images at all.
    case notSupportedByProvider(String)

    public var errorDescription: String? {
        switch self {
        case .contentPolicyViolation(let reason):
            return "Content policy violation\(reason.map { ": \($0)" } ?? "")"
        case .unsupportedSize(let size, let model):
            return "Size \(size.rawValue) is not supported by \(model)"
        case .unsupportedFormat(let format, let model):
            return "Format \(format.rawValue) is not supported by \(model)"
        case .exceedsMaxImages(let requested, let maximum):
            return "Requested \(requested) images, but maximum is \(maximum)"
        case .notSupportedByProvider(let provider):
            return "Image generation is not supported by \(provider)"
        }
    }
}
