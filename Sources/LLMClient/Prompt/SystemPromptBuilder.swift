import Foundation

// MARK: - SystemPromptBuilder

/// The result builder behind the system prompt DSL.
///
/// Lets a prompt be written declaratively, with `if` and `for` in the middle of it. Every method
/// here concatenates in source order and none of them reorder or dedupe, so what is written is what
/// the model reads — which matters, because component order is part of the prompt's behavior.
///
/// ## Example
///
/// ```swift
/// let prompt = SystemPrompt {
///     PromptComponent.role("Data analyst")
///     PromptComponent.objective("Extract information")
///
///     if needsExamples {
///         PromptComponent.example(input: "...", output: "...")
///     }
///
///     for step in thinkingSteps {
///         PromptComponent.thinkingStep(step)
///     }
/// }
/// ```
@resultBuilder
public struct SystemPromptBuilder {

    /// Flattens the statements of a block into one list, in source order.
    ///
    /// - Parameter components: One list per statement in the block.
    public static func buildBlock(_ components: [PromptComponent]...) -> [PromptComponent] {
        components.flatMap { $0 }
    }

    /// Supplies the components of an if statement that has no else branch.
    ///
    /// Swift passes nil when the branch does not run, and the prompt simply omits those components.
    ///
    /// - Parameter component: The branch's components, or nil when it was skipped.
    public static func buildOptional(_ component: [PromptComponent]?) -> [PromptComponent] {
        component ?? []
    }

    /// Supplies the components of the first branch of an if-else statement.
    ///
    /// - Parameter component: The branch's components.
    public static func buildEither(first component: [PromptComponent]) -> [PromptComponent] {
        component
    }

    /// Supplies the components of the second branch of an if-else statement.
    ///
    /// - Parameter component: The branch's components.
    public static func buildEither(second component: [PromptComponent]) -> [PromptComponent] {
        component
    }

    /// Flattens the per-iteration results of a for-in loop, keeping iteration order.
    ///
    /// - Parameter components: One list per iteration.
    public static func buildArray(_ components: [[PromptComponent]]) -> [PromptComponent] {
        components.flatMap { $0 }
    }

    /// Lifts a single component into the list form the builder works in.
    ///
    /// - Parameter expression: A component written on its own line in the block.
    public static func buildExpression(_ expression: PromptComponent) -> [PromptComponent] {
        [expression]
    }

    /// Accepts a ready-made array as one statement of the block.
    ///
    /// This is what lets a computed list — the constraints a schema adapter dropped, say — be
    /// dropped into the DSL without spelling out a loop.
    ///
    /// - Parameter expression: Components produced elsewhere.
    public static func buildExpression(_ expression: [PromptComponent]) -> [PromptComponent] {
        expression
    }

    /// Hands the assembled components back to the caller of the block.
    ///
    /// - Parameter component: The finished list.
    public static func buildFinalResult(_ component: [PromptComponent]) -> [PromptComponent] {
        component
    }

    /// Supplies the components guarded by an availability check.
    ///
    /// - Parameter component: The components inside the availability block.
    public static func buildLimitedAvailability(_ component: [PromptComponent]) -> [PromptComponent] {
        component
    }
}
