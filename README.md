English | [日本語](./README.ja.md)

# LLMClient

A provider-agnostic LLM client abstraction Swift package

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

- **Provider Agnostic** - Unified protocol allows swapping any LLM provider without changing call-site code
- **Swift Macro-based Tool Definition** - Type-safe Function Calling with `@Tool` macro
- **Structured Output** - Type-safe structured responses via `@Structured` macro and JSON Schema
- **Streaming** - Real-time token output via AsyncThrowingStream
- **Chat Management** - Unified API for message history and context management

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-client.git", .upToNextMajor(from: "3.9.0"))
]
```

### Module Structure

Import only the modules you need:

| Module | Purpose |
|--------|---------|
| `LLMCore` | Pure domain layer (`LLMMessage`, `LLMResponse`, `TokenUsage`, `ModelProfile`, etc.) |
| `LLMClient` | Client protocols, structured output, prompt DSL (`@Structured`, `SystemPrompt`, etc.) |
| `LLMTool` | Swift Macro-based tool definitions (`@Tool`, `@ToolArgument`, `ToolSet`) |
| `LLMAgentStep` | Agent loop contract (`AgentCapableClient`, `StreamingAgentEvent`) |
| `LLMChat` | Conversation continuation (`ChatCapableClient`, `ConversationHistory`) |
| `LLMContext` | Context window breakdown and occupancy tracking |
| `LLMMediaKit` | Platform I/O (`UIImage` / `AVFoundation` conversions, etc.) |

## Quick Start

### Structured Output

```swift
import LLMClient

// Define a type with the @Structured macro
@Structured("City information")
struct CityInfo {
    @StructuredField("City name")
    var name: String
    @StructuredField("Population (in ten thousands)")
    var population: Int
}

// Generate via a client (any provider implementation)
let client: any StructuredLLMClient<LLMModel> = // any provider implementation
let city: CityInfo = try await client.generate(
    input: "Tokyo has a population of approximately 14 million",
    model: .claude(.sonnet)
)
print(city.name)       // "Tokyo"
print(city.population) // 1400
```

### Tool Definition

```swift
import LLMTool

@Tool("Get current weather")
struct GetWeather {
    @ToolArgument("City name")
    var city: String

    func call() async throws -> String {
        // Call weather API
        return "Tokyo: Sunny 25°C"
    }
}

let tools = ToolSet {
    GetWeather()
}
```

## Documentation

See the DocC documentation for detailed guides and API reference.

| Guide | Description |
|-------|-------------|
| [API Reference](https://no-problem-dev.github.io/swift-llm-client/documentation/llmclient/) | Full public API |

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## License

MIT License - See [LICENSE](LICENSE) for details

## Links

- [Full Documentation](https://no-problem-dev.github.io/swift-llm-client/documentation/llmclient/)
- [Report Issues](https://github.com/no-problem-dev/swift-llm-client/issues)
- [Discussions](https://github.com/no-problem-dev/swift-llm-client/discussions)
- [Release Process](RELEASE_PROCESS.md)
