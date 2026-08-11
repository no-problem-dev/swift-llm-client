import Foundation

// MARK: - ToolSetBuilder

/// The result builder behind the tool set DSL.
///
/// It supplies the methods the compiler calls for a tool set body, which is why `if`, `if-else`,
/// `for-in` and availability checks all work inside one, the way they do in a SwiftUI view body.
///
/// ## Example
///
/// ```swift
/// let tools = ToolSet {
///     GetWeatherTool(apiKey: apiKey)
///     SearchTool()
///
///     if needsCalculator {
///         CalculatorTool()
///     }
///
///     for tool in additionalTools {
///         tool
///     }
/// }
/// ```
@resultBuilder
public struct ToolSetBuilder {

    // MARK: - Block Building

    /// Flattens the statements of a builder body into one list, keeping their order.
    ///
    /// - Parameter tools: The list contributed by each statement in the body.
    public static func buildBlock(_ tools: [any Tool]...) -> [any Tool] {
        tools.flatMap { $0 }
    }

    // MARK: - Expression Building

    /// Lifts a single tool written in the body into a list of one.
    ///
    /// - Parameter tool: The tool named by the statement.
    public static func buildExpression(_ tool: some Tool) -> [any Tool] {
        [tool]
    }

    /// Splices an array of tools into the body without nesting it.
    ///
    /// Use it when the tools are already in an array rather than written out one by one.
    ///
    /// - Parameter tools: The tools to splice in.
    public static func buildExpression(_ tools: [any Tool]) -> [any Tool] {
        tools
    }

    // MARK: - Conditional Building

    /// Contributes nothing when the condition of an `if` without an `else` is false.
    ///
    /// - Parameter tools: The tools from the branch, or `nil` when it was not taken.
    public static func buildOptional(_ tools: [any Tool]?) -> [any Tool] {
        tools ?? []
    }

    /// Takes the tools from the `if` branch of an `if-else`.
    ///
    /// - Parameter tools: The tools from that branch.
    public static func buildEither(first tools: [any Tool]) -> [any Tool] {
        tools
    }

    /// Takes the tools from the `else` branch of an `if-else`.
    ///
    /// - Parameter tools: The tools from that branch.
    public static func buildEither(second tools: [any Tool]) -> [any Tool] {
        tools
    }

    // MARK: - Array Building

    /// Flattens the per-iteration results of a `for-in` loop, keeping iteration order.
    ///
    /// - Parameter tools: The list contributed by each pass through the loop.
    public static func buildArray(_ tools: [[any Tool]]) -> [any Tool] {
        tools.flatMap { $0 }
    }

    // MARK: - Final Result

    /// Hands the assembled list back as the value of the builder body.
    ///
    /// - Parameter tools: The tools gathered from the whole body.
    public static func buildFinalResult(_ tools: [any Tool]) -> [any Tool] {
        tools
    }

    // MARK: - Availability

    /// Erases the availability of tools declared inside an availability check.
    ///
    /// - Parameter tools: The tools from inside the `#available` block.
    public static func buildLimitedAvailability(_ tools: [any Tool]) -> [any Tool] {
        tools
    }
}
