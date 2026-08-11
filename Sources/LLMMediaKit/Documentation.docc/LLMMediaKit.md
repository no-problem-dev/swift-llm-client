# ``LLMMediaKit``

Turn generated media into the platform types you can actually display or play.

## Overview

`LLMCore` describes generated media as bytes plus a format, and stops there on purpose: pulling
`UIKit` or `AVFoundation` into the domain layer would make it unbuildable wherever those
frameworks are absent. `LLMMediaKit` is where that boundary is crossed, in one small target you
can choose not to link.

Everything here is an extension on a `LLMCore` type, guarded by `#if canImport(...)`. Adding the
library to a target on any platform is safe; the members simply do not exist where the
underlying framework does not.

**Images.** `uiImage` returns a `UIImage` where UIKit is available (iOS, tvOS, watchOS, and
Catalyst); ``LLMCore/GeneratedImage/nsImage`` returns an `NSImage` on macOS. Where CoreGraphics
is available, ``LLMCore/GeneratedImage/cgImage`` and ``LLMCore/GeneratedImage/imageSize`` work on
either. All of them decode the stored bytes on each access and return `nil` if the data is not a
readable image, so hold on to the result rather than calling them in a view body.

**Audio.** ``LLMCore/GeneratedAudio/audioPlayer`` builds an `AVAudioPlayer` from the stored
bytes, ready to `play()`.

**Video.** ``LLMCore/GeneratedVideo/downloadData()`` fetches the bytes for a video the provider
returned as a URL rather than inline. Provider-hosted media URLs are usually short-lived, so
download early if you intend to keep it.

```swift
import LLMMediaKit
import LLMCore

#if canImport(UIKit)
if let image = generatedImage.uiImage {
    imageView.image = image
}
#endif

#if canImport(AVFoundation)
generatedAudio.audioPlayer?.play()
#endif
```

## Topics

### Images

- ``LLMCore/GeneratedImage/nsImage``
- ``LLMCore/GeneratedImage/cgImage``
- ``LLMCore/GeneratedImage/imageSize``

### Audio

- ``LLMCore/GeneratedAudio/audioPlayer``

### Video

- ``LLMCore/GeneratedVideo/downloadData()``
