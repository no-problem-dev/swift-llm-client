// swift-llm-client
//
// Bridges from generated image bytes to the platform's own image types.

import Foundation
import LLMCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

extension GeneratedImage {
    #if canImport(UIKit)
    /// The image decoded into UIKit's image type.
    ///
    /// Available where UIKit is — iOS, tvOS, watchOS, visionOS, and Mac Catalyst. Nil when the bytes
    /// cannot be decoded, which includes WebP on systems whose image decoders predate support for
    /// it. Decoding runs on every access, so hold on to the result rather than reading it in a view
    /// body.
    public var uiImage: UIImage? {
        UIImage(data: data)
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// The image decoded into AppKit's image type.
    ///
    /// Available on macOS, but not under Mac Catalyst, where UIKit's image type applies instead.
    /// Nil when the bytes cannot be decoded. Decoding runs on every access.
    public var nsImage: NSImage? {
        NSImage(data: data)
    }
    #endif

    #if canImport(CoreGraphics)
    /// The image decoded into a Core Graphics image.
    ///
    /// Available wherever Core Graphics is, which is every Apple platform. It goes through the
    /// UIKit or AppKit representation, so it is nil for the same reasons those are, and nil outright
    /// on a platform that has Core Graphics but neither UI framework. Decoding runs on every access.
    public var cgImage: CGImage? {
        #if canImport(UIKit)
        return uiImage?.cgImage
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return nsImage?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
    #endif

    /// The pixel dimensions of the image, read from the decoded bitmap.
    ///
    /// These are true pixels, not points: no screen scale is applied. Nil on platforms without Core
    /// Graphics and whenever the bytes fail to decode. Getting the size decodes the whole image, so
    /// it is not a cheap read.
    public var imageSize: (width: Int, height: Int)? {
        #if canImport(CoreGraphics)
        guard let cgImage = cgImage else { return nil }
        return (width: cgImage.width, height: cgImage.height)
        #else
        return nil
        #endif
    }
}
