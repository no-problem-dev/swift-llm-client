// swift-llm-client
//
// Bridge from generated audio bytes to the platform's own player.

import Foundation
import LLMCore

#if canImport(AVFoundation)
import AVFoundation
#endif

extension GeneratedAudio {
    #if canImport(AVFoundation)
    /// A player primed with the audio, ready to start.
    ///
    /// Available wherever AVFoundation is. Each access builds a new player over the same bytes, so
    /// keep the one you start — a player released mid-playback stops. Errors are swallowed and
    /// surface as nil.
    ///
    /// Nil for raw PCM, which is what Gemini TTS returns: the samples carry no container and no
    /// header, so the player has no sample rate to go on. Wrap them in a WAV header, or play them
    /// through an audio engine that is told the format, before expecting sound.
    public var audioPlayer: AVAudioPlayer? {
        try? AVAudioPlayer(data: data)
    }
    #endif
}
