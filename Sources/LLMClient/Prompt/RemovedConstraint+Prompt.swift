import Foundation

// MARK: - RemovedConstraint to PromptComponent Conversion

extension RemovedConstraint {
    /// Restates a constraint the schema could not carry as an instruction the model can read.
    ///
    /// This is the second half of a round trip. A field constraint starts life as a JSON Schema
    /// keyword; a provider's schema adapter strips the keywords that provider rejects and records
    /// each one as a removed constraint; this turns the record back into an output constraint
    /// component so the requirement is at least stated in words.
    ///
    /// What is lost in the round trip is enforcement. A keyword in the schema is checked by the
    /// provider's decoder, while a sentence in the prompt is only a request the model usually
    /// honors — so validate the decoded value yourself when the bound has to hold.
    ///
    /// - Returns: An output constraint component holding one English sentence.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let constraint = RemovedConstraint(
    ///     type: .minItems,
    ///     fieldPath: "tags",
    ///     value: .int(1)
    /// )
    /// let component = constraint.toPromptComponent()
    /// // → .outputConstraint("The 'tags' array must have at least 1 item(s).")
    /// ```
    public func toPromptComponent() -> PromptComponent {
        .outputConstraint(toConstraintDescription())
    }

    /// Writes the constraint as one English sentence naming the field and the bound.
    ///
    /// The text is always English regardless of the prompt's language, and the field is quoted by
    /// its path, so a nested field reads as `'user.age'` and an array element as `'items[].count'`.
    private func toConstraintDescription() -> String {
        let field = formatFieldPath(fieldPath)

        switch type {
        case .minimum:
            return "The '\(field)' field must be at least \(value.stringValue)."

        case .maximum:
            return "The '\(field)' field must be at most \(value.stringValue)."

        case .exclusiveMinimum:
            return "The '\(field)' field must be greater than \(value.stringValue) (exclusive)."

        case .exclusiveMaximum:
            return "The '\(field)' field must be less than \(value.stringValue) (exclusive)."

        case .minItems:
            return "The '\(field)' array must have at least \(value.stringValue) item(s)."

        case .maxItems:
            return "The '\(field)' array must have at most \(value.stringValue) item(s)."

        case .minLength:
            return "The '\(field)' field must be at least \(value.stringValue) character(s) long."

        case .maxLength:
            return "The '\(field)' field must be at most \(value.stringValue) character(s) long."

        case .pattern:
            return "The '\(field)' field must match the pattern: \(value.stringValue)"

        case .format:
            return "The '\(field)' field must be in \(value.stringValue) format."
        }
    }

    /// Turns a field path into something a sentence can name.
    private func formatFieldPath(_ path: String) -> String {
        // The root schema has no field name of its own, so call it the response.
        if path.isEmpty || path == "$" {
            return "response"
        }
        return path
    }
}

// MARK: - Array Extension

extension Array where Element == RemovedConstraint {
    /// Restates every dropped constraint as an output constraint component.
    ///
    /// One component per constraint, in the order the adapter recorded them, which is the order the
    /// model will read them in.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let constraints = [
    ///     RemovedConstraint(type: .minItems, fieldPath: "tags", value: .int(1)),
    ///     RemovedConstraint(type: .maxItems, fieldPath: "tags", value: .int(5))
    /// ]
    /// let components = constraints.toPromptComponents()
    /// ```
    public func toPromptComponents() -> [PromptComponent] {
        map { $0.toPromptComponent() }
    }

    /// Collects the dropped constraints into a prompt of their own, or nil when none were dropped.
    ///
    /// Returning nil rather than an empty prompt is what keeps the append conditional: a provider
    /// that accepted the whole schema leaves the system prompt untouched, byte for byte, and any
    /// cached prefix intact.
    ///
    /// - Returns: A prompt of output constraint components, or nil when the array is empty.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let constraintPrompt = removedConstraints.toSystemPrompt() {
    ///     let finalPrompt = systemPrompt + constraintPrompt
    /// }
    /// ```
    public func toSystemPrompt() -> SystemPrompt? {
        guard !isEmpty else { return nil }
        return SystemPrompt(components: toPromptComponents())
    }
}

// MARK: - SchemaAdaptationResult Extension

extension SchemaAdaptationResult {
    /// The constraints this adaptation had to drop, written as a prompt.
    ///
    /// Sending it is the caller's job: adapting a schema does not touch the system prompt, so a
    /// result whose constraints are never appended silently loses them. Append rather than prepend
    /// — the components belong after the existing prompt so the earlier text stays cacheable.
    ///
    /// - Returns: A prompt of output constraint components, or nil when nothing was dropped.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let adapter = OpenAISchemaAdapter()
    /// let result = adapter.adaptWithConstraints(schema)
    ///
    /// if let constraintPrompt = result.toConstraintSystemPrompt() {
    ///     // Add the constraints to the system prompt
    ///     let effectiveSystemPrompt = systemPrompt + constraintPrompt
    /// }
    /// ```
    public func toConstraintSystemPrompt() -> SystemPrompt? {
        removedConstraints.toSystemPrompt()
    }
}
