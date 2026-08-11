English | [日本語](./README.ja.md)

# LLMClient

One Swift API for Claude, GPT, Gemini, Grok, Groq, Mistral and DeepSeek — with type-safe structured output and tool calling.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

- **Provider agnostic** — swap providers without touching call-site code
- **Structured output** — decode straight into your own type via the `@Structured` macro and JSON Schema
- **Tool calling** — declare tools with the `@Tool` macro; arguments stay type-safe on both sides
- **Streaming** — text, reasoning and tool-argument deltas over `AsyncThrowingStream`
- **Token accounting** — usage, prompt-cache tiers, cost and live context-window occupancy

## Quick Start

Describe the shape you want, and get it back decoded:

```swift
import LLMClient

@Structured("City information")
struct CityInfo {
    @StructuredField("City name")
    var name: String

    @StructuredField("Population, in units of ten thousand")
    var population: Int
}

let city: CityInfo = try await client.generate(
    input: "Tokyo has a population of roughly 14 million.",
    model: .claude(.sonnet)
)

print(city.name)       // "Tokyo"
print(city.population) // 1400
```

Declare a tool the same way, and let the model call it:

```swift
import LLMTool

@Tool("Get the current weather for a city")
struct GetWeather {
    @ToolArgument("City name")
    var city: String

    func call() async throws -> String {
        "\(city): sunny, 25°C"
    }
}

let plan = try await client.planToolCalls(
    prompt: "Compare the weather in Tokyo and Osaka.",
    model: .claude(.sonnet),
    tools: ToolSet { GetWeather() }
)
```

`client` is any type conforming to `StructuredLLMClient` / `ToolCallableClient`; provider
implementations live in separate packages.

## Documentation

The full API reference and guides are hosted at
[no-problem-dev.github.io/swift-llm-client](https://no-problem-dev.github.io/swift-llm-client/documentation/llmclient/).
Start with **Getting Started**, and read **Module Layout** to decide which of the nine
libraries to import.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-client.git", from: "3.0.0")
]
```

Then add the libraries you need — `LLMClient` and `LLMTool` cover most uses:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "LLMClient", package: "swift-llm-client"),
        .product(name: "LLMTool", package: "swift-llm-client"),
    ]
)
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## License

MIT License — see [LICENSE](LICENSE).
