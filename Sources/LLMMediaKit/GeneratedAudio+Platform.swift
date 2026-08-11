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
    /// keep the one you start — a player released mid-playback stops.
    ///
    /// It throws AVFoundation's own error rather than answering nil, because the two reasons a
    /// caller has to tell apart look identical from a nil: raw PCM, which is what Gemini TTS
    /// returns and which carries no container and no header for the player to read a sample rate
    /// from, and bytes that are simply truncated or corrupt. The first is answered by wrapping the
    /// samples in a WAV header or playing them through an audio engine that is told the format;
    /// the second by fetching them again.
    ///
    /// - Throws: The error AVFoundation raised, unwrapped, naming why the bytes could not be played.
    public var audioPlayer: AVAudioPlayer {
        get throws {
            try AVAudioPlayer(data: data)
        }
    }
    #endif
}
