// swift-llm-client
//
// GeneratedImage のプラットフォーム便利機能

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
    /// UIImage に変換（iOS/tvOS/watchOS/visionOS）
    public var uiImage: UIImage? {
        UIImage(data: data)
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// NSImage に変換（macOS）
    public var nsImage: NSImage? {
        NSImage(data: data)
    }
    #endif

    #if canImport(CoreGraphics)
    /// CGImage に変換
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

    /// 画像のサイズ（ピクセル）
    public var imageSize: (width: Int, height: Int)? {
        #if canImport(CoreGraphics)
        guard let cgImage = cgImage else { return nil }
        return (width: cgImage.width, height: cgImage.height)
        #else
        return nil
        #endif
    }
}
