/// キャンセル伝播が保証された `AsyncThrowingStream` を生成するユーティリティ。
///
/// 通常の `AsyncThrowingStream { continuation in Task { ... } }` パターンでは
/// `onTermination` の設定を忘れるとキャンセルが内部 Task に伝播しない。
/// この関数は呼び出し側に inner Task の返却を **型レベルで強制** し、
/// `onTermination` 未設定を構造的に防止する。
///
/// ## 使用例
///
/// ```swift
/// func generate() -> AsyncThrowingStream<String, Error> {
///     makeCancellableStream { continuation in
///         Task {
///             for try await token in someSource {
///                 try Task.checkCancellation()
///                 continuation.yield(token)
///             }
///             continuation.finish()
///         }
///     }
/// }
/// ```
///
/// ストリームの消費側がイテレーションを中断すると、`onTermination` 経由で
/// 返却された Task が自動的にキャンセルされる。
public func makeCancellableStream<T: Sendable>(
    _ build: @Sendable @escaping (AsyncThrowingStream<T, Error>.Continuation) -> Task<Void, Never>
) -> AsyncThrowingStream<T, Error> {
    AsyncThrowingStream { continuation in
        let innerTask = build(continuation)
        continuation.onTermination = { _ in
            innerTask.cancel()
        }
    }
}
