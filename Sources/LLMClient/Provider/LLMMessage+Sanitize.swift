import Foundation

extension Array where Element == LLMMessage {
    /// Repairs a history in which a tool call was never answered, by inserting a synthetic failure
    /// result for each unanswered call.
    ///
    /// When an app crashes or times out while a tool is running, the assistant message keeps its
    /// `tool_use` block but the matching `tool_result` never arrives. Sending that history gets the
    /// whole request rejected — Anthropic answers `tool_use ids were found without tool_result
    /// blocks`. Call this immediately before sending to make such a history acceptable again.
    ///
    /// **This rewrites the conversation, and the model sees the rewrite.** Every unanswered call is
    /// answered with the literal text `Error: Tool execution was interrupted unexpectedly. Please
    /// retry.`, which becomes part of the history and may well prompt the model to run the tool
    /// again. Nothing is logged and nothing is thrown, so a caller who needs to know that a repair
    /// happened must compare the array before and after.
    ///
    /// Precisely what it does, walking the array once from the front, for each assistant message
    /// holding `tool_use` blocks:
    ///
    /// - If the **next** message is a user message, the missing results are appended to it — after
    ///   whatever content it already holds, not before it. Existing results are left alone.
    /// - Otherwise (the assistant message is last, or is followed by another assistant message), a
    ///   new user message holding results for *all* of that message's tool calls is inserted
    ///   directly after it.
    ///
    /// What it does not do, so a caller does not assume otherwise: it never removes or reorders
    /// anything; it does not drop a `tool_result` whose `tool_use` is missing (the mirror-image
    /// problem, which providers also reject); it does not merge consecutive same-role messages or
    /// remove messages with empty content; and it only ever inspects the single message following
    /// a tool call, so a result placed two messages later still counts as missing and gets a second,
    /// synthetic answer.
    public mutating func sanitizeOrphanedToolUses() {
        var i = 0
        while i < count {
            let message = self[i]
            guard message.role == .assistant else {
                i += 1
                continue
            }

            // Collect the tool_use IDs in this assistant message.
            let toolUseIds = message.contents.compactMap { content -> (id: String, name: String)? in
                guard case .toolUse(let id, let name, _) = content else { return nil }
                return (id: id, name: name)
            }

            guard !toolUseIds.isEmpty else {
                i += 1
                continue
            }

            // Check whether the next message is a user message carrying tool_result blocks.
            let nextIndex = i + 1
            if nextIndex < count {
                let nextMessage = self[nextIndex]
                if nextMessage.role == .user {
                    let existingResultIds = Set(
                        nextMessage.contents.compactMap { content -> String? in
                            guard case .toolResult(let toolCallId, _, _) = content else {
                                return nil
                            }
                            return toolCallId
                        }
                    )

                    // Work out which tool_result blocks are missing.
                    let missingIds = toolUseIds.filter { !existingResultIds.contains($0.id) }

                    if missingIds.isEmpty {
                        // Every call already has its result.
                        i += 1
                        continue
                    }

                    // Append the missing results to the existing user message.
                    let syntheticResults = missingIds.map { missing in
                        LLMMessage.MessageContent.toolResult(
                            toolCallId: missing.id,
                            name: missing.name,
                            content: .failure("Error: Tool execution was interrupted unexpectedly. Please retry.")
                        )
                    }
                    let mergedContents = nextMessage.contents + syntheticResults
                    self[nextIndex] = LLMMessage(role: .user, contents: mergedContents)
                    i += 1
                    continue
                }
            }

            // No next message, or the next message is not a user message:
            // insert a synthetic result for every tool_use.
            let syntheticContents = toolUseIds.map { toolUse in
                LLMMessage.MessageContent.toolResult(
                    toolCallId: toolUse.id,
                    name: toolUse.name,
                    content: .failure("Error: Tool execution was interrupted unexpectedly. Please retry.")
                )
            }
            let syntheticMessage = LLMMessage(role: .user, contents: syntheticContents)
            insert(syntheticMessage, at: nextIndex)
            i += 1  // skip the inserted message
        }
    }
}
