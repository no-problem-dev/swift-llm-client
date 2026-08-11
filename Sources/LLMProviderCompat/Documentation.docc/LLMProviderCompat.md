# ``LLMProviderCompat``

Find out that a provider cannot take your media before you send it, not from the error it returns.

## Overview

Providers accept different media. Anthropic takes no audio at all; OpenAI takes a short list of
audio formats; Gemini accepts image types the others reject. When you get it wrong, the failure
arrives as an opaque HTTP error after you have already paid for the upload — and the message
rarely names the offending attachment.

`LLMProviderCompat` moves that check to before the call.

**Capabilities.** ``ProviderCapabilities`` is the interface a provider implements to declare what
it supports: which modalities, which MIME types, which directions (input versus generation).
``ProviderType`` enumerates the built-in providers with their default capability sets, so the
common case needs no configuration.

**Validation.** ``MediaCompatibility`` answers the question two ways. `isSupported` is a boolean
for building UI — hide the attachment button rather than letting the user hit a wall.
`validate` throws ``ProviderCompatibilityError``, naming the media type and the provider, which
is what you want on the path to the request.

```swift
import LLMProviderCompat

let supportsAudio = MediaCompatibility.isSupported(AudioMediaType.mp3, by: .anthropic) // false
let supportsJpeg  = MediaCompatibility.isSupported(ImageMediaType.jpeg, by: .openai)   // true

let image = ImageContent(source: .base64(mimeType: "image/heic", data: heicData))
do {
    try MediaCompatibility.validate(image, for: .openai)
} catch let error as ProviderCompatibilityError {
    print(error.localizedDescription)
    // "Media type 'image/heic' is not supported by OpenAI"
}
```

These are static facts about providers, not live probes. A provider that adds a format ships in
a release of this package, so treat a `false` as "not known to be supported" rather than as
proof of rejection.

## Topics

### Declaring capabilities

- ``ProviderCapabilities``
- ``ProviderType``

### Checking a request

- ``MediaCompatibility``
- ``ProviderCompatibilityError``
