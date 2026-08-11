import Foundation

// MARK: - PromptComponent

/// One tagged section of a system prompt.
///
/// The DSL exists so that established prompt-engineering techniques can be mixed freely instead of
/// being spelled out as one long string. Each case renders as an XML-style element whose tag name
/// is fixed by the case, and the model sees those tags verbatim.
///
/// Two things reach the model that a caller might mistake for formatting. The tag name is one; the
/// order the cases are written in is the other. Reordering a prompt is a behavior change, not a
/// cosmetic one. Repeating a case emits a separate element each time — nothing merges or dedupes.
///
/// ## Example
///
/// ```swift
/// let prompt = SystemPrompt {
///     PromptComponent.role("Data analysis expert")
///     PromptComponent.objective("Extract information from text")
///     PromptComponent.instruction("Strip honorifics from names")
///     PromptComponent.constraint("Never guess")
/// }
/// ```
///
/// ## Categories
///
/// - **Persona**: `role`, `expertise`, `behavior`
/// - **Task definition**: `objective`, `context`, `instruction`, `constraint`
/// - **Chain-of-thought**: `thinkingStep`, `reasoning`
/// - **Few-shot**: `example`
/// - **Meta**: `important`, `note`
public enum PromptComponent: Sendable, Equatable, Codable {

    // MARK: - Persona

    /// The role the model answers from.
    ///
    /// A role makes the model answer from that perspective. Use it for the identity only; the
    /// domain knowledge belongs in `expertise` and the tone in `behavior`.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.role("Seasoned Swift engineer")
    /// ```
    case role(String)

    /// The specialist knowledge that comes with the role.
    ///
    /// Write one element per area rather than a single sentence listing them; each call emits its
    /// own tag, which the model reads as separate claims.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.expertise("iOS app development")
    /// PromptComponent.expertise("Performance tuning")
    /// ```
    case expertise(String)

    /// The manner the answers should take.
    ///
    /// Style and attitude, not content. Use it when the answer is right but reads wrong.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.behavior("Give concise, practical advice")
    /// ```
    case behavior(String)

    // MARK: - Task definition

    /// The goal the prompt is aiming at.
    ///
    /// State the outcome rather than the steps; the steps belong in `instruction`.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.objective("Extract user information as JSON")
    /// ```
    case objective(String)

    /// The background the task sits in.
    ///
    /// Describes the situation and the shape of the input. This is also the case a bare string
    /// literal turns into, so a prompt written as a plain string arrives at the model wrapped in a
    /// context element.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.context("The input is a social media post written in Japanese")
    /// ```
    case context(String)

    /// A concrete step for carrying the task out.
    ///
    /// One action per element. Instructions say what to do; `constraint` says what not to do, and
    /// models follow the two more reliably when they are kept apart.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.instruction("Strip honorifics such as Mr. or Ms. from names")
    /// PromptComponent.instruction("Extract ages as bare numbers")
    /// ```
    case instruction(String)

    /// A limit or prohibition on the answer.
    ///
    /// Business rules, not schema rules — a numeric range or an array length belongs in
    /// `outputConstraint`, which the schema layer generates.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.constraint("Never guess")
    /// PromptComponent.constraint("Use only information stated explicitly")
    /// ```
    case constraint(String)

    // MARK: - Chain-of-thought

    /// A step in the reasoning the model should follow.
    ///
    /// Chain-of-thought prompting: naming the steps shapes how the model reaches its answer. It
    /// shapes the process, not the output — under structured output there is nowhere for a visible
    /// trace to go, and with a model that already produces its own reasoning tokens this mostly
    /// adds input tokens for little gain.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.thinkingStep("First identify the personal names in the text")
    /// PromptComponent.thinkingStep("Then look for any mention of age")
    /// ```
    case thinkingStep(String)

    /// Why the task is done the way it is.
    ///
    /// Stating the reason behind a rule helps the model generalize it to inputs the instructions
    /// never covered, instead of applying it literally.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.reasoning("Honorifics are stripped so the values normalize in the database")
    /// ```
    case reasoning(String)

    // MARK: - Few-shot

    /// A worked input and the output expected for it.
    ///
    /// Few-shot prompting, and usually the fastest fix for output that is nearly right. Examples
    /// are rendered inline into the system prompt, so they are charged as input tokens on every
    /// request: a fixed set is worth caching, while examples rebuilt per request keep the provider
    /// from reusing a cached prefix.
    ///
    /// - Parameters:
    ///   - input: The sample input.
    ///   - output: The output the model should produce for it.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.example(
    ///     input: "Hanako Sato (28) lives in Tokyo",
    ///     output: #"{"name": "Hanako Sato", "age": 28}"#
    /// )
    /// ```
    case example(input: String, output: String)

    // MARK: - Meta

    /// A point to be weighted above the rest.
    ///
    /// Reserve it for the one or two rules that must not be missed; emphasizing everything
    /// emphasizes nothing.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.important("Always return null for information you do not have")
    /// ```
    case important(String)

    /// A supplementary hint.
    ///
    /// Edge cases and quirks of the input that are worth knowing but do not change the task.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.note("Dates may be written in either the Western or the Japanese era")
    /// ```
    case note(String)

    // MARK: - Output constraints

    /// A schema rule restated for the model in words.
    ///
    /// Providers accept different subsets of JSON Schema, and a schema adapter strips the keywords
    /// its provider rejects. This case is where those dropped keywords land, so it is usually
    /// generated rather than written by hand — see `RemovedConstraint.toPromptComponent()`. Nothing
    /// validates against it: once the keyword is out of the schema, the sentence is the only thing
    /// left asking for it.
    ///
    /// ## Example
    /// ```swift
    /// PromptComponent.outputConstraint("The 'age' field must be at least 0.")
    /// PromptComponent.outputConstraint("The 'tags' array must have at most 5 item(s).")
    /// ```
    ///
    /// ## How it differs from a constraint
    ///
    /// - `constraint`: a business rule, such as never guessing
    /// - `outputConstraint`: a technical bound on the value, such as a numeric range or array length
    case outputConstraint(String)
}

// MARK: - Rendering

extension PromptComponent {

    /// The XML tag this case renders as.
    ///
    /// Part of the prompt contract, not a display detail: the model is trained on what these tags
    /// delimit, so a different name is a different prompt. Two names are not derivable from the
    /// case — `thinkingStep` renders as `thinking_step` and `outputConstraint` as
    /// `output_constraint`. Those are the strings to pass to `SystemPrompt.components(withTag:)`.
    public var tagName: String {
        switch self {
        case .role: return "role"
        case .expertise: return "expertise"
        case .behavior: return "behavior"
        case .objective: return "objective"
        case .context: return "context"
        case .instruction: return "instruction"
        case .constraint: return "constraint"
        case .thinkingStep: return "thinking_step"
        case .reasoning: return "reasoning"
        case .example: return "example"
        case .important: return "important"
        case .note: return "note"
        case .outputConstraint: return "output_constraint"
        }
    }

    /// The text without its tags, for showing in a UI.
    ///
    /// Not what the model receives. An example collapses onto one line joined by an arrow here,
    /// whereas rendering puts the input and the output on separate lines.
    public var contentPreview: String {
        switch self {
        case .role(let value),
             .expertise(let value),
             .behavior(let value),
             .objective(let value),
             .context(let value),
             .instruction(let value),
             .constraint(let value),
             .thinkingStep(let value),
             .reasoning(let value),
             .important(let value),
             .note(let value),
             .outputConstraint(let value):
            return value

        case .example(let input, let output):
            return "Input: \(input) → Output: \(output)"
        }
    }

    /// Renders the component as a pseudo-XML element.
    ///
    /// Prompt tags are a delimiting convention rather than real syntax, so the content is never
    /// escaped. Pre-rendered tags, JSON, and code fragments can be embedded as they are — and by
    /// the same token, a value that happens to contain a closing tag will break the delimiting.
    public func render() -> String {
        switch self {
        case .role(let value),
             .expertise(let value),
             .behavior(let value),
             .objective(let value),
             .context(let value),
             .instruction(let value),
             .constraint(let value),
             .thinkingStep(let value),
             .reasoning(let value),
             .important(let value),
             .note(let value),
             .outputConstraint(let value):
            return "<\(tagName)>\(value)</\(tagName)>"

        case .example(let input, let output):
            return "<\(tagName)>Input: \(input)\nOutput: \(output)</\(tagName)>"
        }
    }
}

// MARK: - CustomStringConvertible

extension PromptComponent: CustomStringConvertible {
    public var description: String {
        render()
    }
}


