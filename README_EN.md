English | [日本語](README.md)

# LLMClient

A provider-agnostic LLM client abstraction Swift package

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

- **Provider Agnostic** - Unified protocol allows swapping any LLM provider
- **Swift Macro-based Tool Definition** - Type-safe Function Calling with `@LLMTool` macro
- **Structured Output** - Dynamic structured responses based on JSON Schema
- **Streaming** - Real-time token output via AsyncThrowingStream
- **Chat Management** - Unified API for message history and context management

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-llm-client.git", .upToNextMajor(from: "1.0.0"))
]
```

### Module Structure

Import only the modules you need:

| Module | Purpose |
|--------|---------|
| `LLMClient` | Core protocols and types (LLMProvider, LLMMessage, LLMResponse, etc.) |
| `LLMTool` | Swift Macro-based tool definitions (`@LLMTool`, ToolSet) |
| `LLMChat` | Chat message management (history, context) |
| `LLMDynamicStructured` | Dynamic JSON Schema-based structured output |

## Quick Start

### Using an LLM Provider

```swift
import LLMClient

// Stream generation with a provider
let provider: any LLMProvider = // any provider implementation
for try await chunk in provider.stream(messages: [
    .user("Explain Swift's async/await")
]) {
    print(chunk.text, terminator: "")
}
```

### Tool Definition

```swift
import LLMTool

@LLMTool("Get current weather")
struct GetWeather {
    @LLMToolParameter("City name")
    var city: String

    func execute() async throws -> String {
        // Call weather API
        return "Tokyo: Sunny 25°C"
    }
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
