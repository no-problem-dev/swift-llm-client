// swift-llm-client
//
// GeneratedAudio のプラットフォーム便利機能

import Foundation
import LLMCore

#if canImport(AVFoundation)
import AVFoundation
#endif

extension GeneratedAudio {
    #if canImport(AVFoundation)
    /// AVAudioPlayer を作成
    ///
    /// - Note: PCM フォーマットの場合、追加の変換が必要になる場合があります
    public var audioPlayer: AVAudioPlayer? {
        try? AVAudioPlayer(data: data)
    }
    #endif
}
