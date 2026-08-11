/// Builds a throwing stream whose producing task is cancelled when the consumer walks away.
///
/// In the usual `AsyncThrowingStream { continuation in Task { ... } }` shape, forgetting to set
/// `onTermination` leaves the inner task alive after nobody is reading: a streamed request keeps
/// running against the provider and keeps generating billable tokens into a stream nobody consumes.
/// This function takes the inner task as the builder's return value, so the wiring cannot be
/// omitted without the code failing to compile.
///
/// ## Example
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
/// When iteration stops — the consuming task is cancelled, the iterator is dropped, or the producer
/// finishes normally — termination cancels the returned task. Cancellation only takes effect where
/// the producer checks for it, so a long provider call in flight ends at the next
/// `Task.checkCancellation()` or cancellation-aware await, not instantly.
///
/// - Parameter build: Starts producing values and returns the task doing it, which is the task that
///   gets cancelled on termination.
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
