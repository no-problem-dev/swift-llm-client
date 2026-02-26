import Foundation

extension Array where Element == LLMMessage {
    /// 孤立した `tool_use` に対して合成 `tool_result` を挿入し、メッセージ履歴を修復する
    ///
    /// ツール実行中にアプリがクラッシュ・タイムアウトすると、
    /// assistant メッセージの `tool_use` に対応する `tool_result` が存在しない状態になる。
    /// この状態で LLM API を呼ぶと `tool_use ids were found without tool_result blocks` エラーが発生する。
    ///
    /// この関数は LLM API 呼び出し前に呼んで、孤立した `tool_use` を検出し、
    /// エラーの `tool_result` を合成挿入することでメッセージ履歴を修復する。
    public mutating func sanitizeOrphanedToolUses() {
        var i = 0
        while i < count {
            let message = self[i]
            guard message.role == .assistant else {
                i += 1
                continue
            }

            // この assistant メッセージ内の tool_use ID を収集
            let toolUseIds = message.contents.compactMap { content -> (id: String, name: String)? in
                guard case .toolUse(let id, let name, _) = content else { return nil }
                return (id: id, name: name)
            }

            guard !toolUseIds.isEmpty else {
                i += 1
                continue
            }

            // 次のメッセージが user で tool_result を含むか確認
            let nextIndex = i + 1
            if nextIndex < count {
                let nextMessage = self[nextIndex]
                if nextMessage.role == .user {
                    let existingResultIds = Set(
                        nextMessage.contents.compactMap { content -> String? in
                            guard case .toolResult(let toolCallId, _, _, _) = content else {
                                return nil
                            }
                            return toolCallId
                        }
                    )

                    // 不足している tool_result を特定
                    let missingIds = toolUseIds.filter { !existingResultIds.contains($0.id) }

                    if missingIds.isEmpty {
                        // すべて揃っている
                        i += 1
                        continue
                    }

                    // 既存の user メッセージに不足分を追加
                    let syntheticResults = missingIds.map { missing in
                        LLMMessage.MessageContent.toolResult(
                            toolCallId: missing.id,
                            name: missing.name,
                            content: "Error: Tool execution was interrupted unexpectedly. Please retry.",
                            isError: true
                        )
                    }
                    let mergedContents = nextMessage.contents + syntheticResults
                    self[nextIndex] = LLMMessage(role: .user, contents: mergedContents)
                    i += 1
                    continue
                }
            }

            // 次のメッセージが存在しないか、user ロールでない場合
            // → すべての tool_use に対して合成 tool_result を挿入
            let syntheticContents = toolUseIds.map { toolUse in
                LLMMessage.MessageContent.toolResult(
                    toolCallId: toolUse.id,
                    name: toolUse.name,
                    content: "Error: Tool execution was interrupted unexpectedly. Please retry.",
                    isError: true
                )
            }
            let syntheticMessage = LLMMessage(role: .user, contents: syntheticContents)
            insert(syntheticMessage, at: nextIndex)
            i += 1  // skip the inserted message
        }
    }
}
