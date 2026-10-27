// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

/// A handle to an in-flight Nexio request.
///
/// - Note: No public Nexio API currently returns a `NexioRequest`. To cancel a
///   request, cancel the `Task` that awaits it. Cancelling the task stops
///   retries and the underlying network call, and the await throws
///   `CancellationError`.
///
/// ```swift
/// let task = Task {
///     let users: [User] = try await NexioClient.shared.get("/users")
///     return users
/// }
/// // Later:
/// task.cancel()
/// ```
@available(*, deprecated, message: "Cancel the awaiting Task instead; Nexio never returns NexioRequest.")
public final class NexioRequest: Sendable {

    private let task: _TaskBox

    /// Cancels the underlying network task.
    public func cancel() {
        task.cancel()
    }

    init(urlSessionTask: URLSessionTask) {
        task = _TaskBox(urlSessionTask)
    }
}

// MARK: - Private box for URLSessionTask (non-Sendable bridging)

/// Wraps `URLSessionTask` so `NexioRequest` can be `Sendable`.
/// `URLSessionTask` is thread-safe for `cancel()` calls per Apple's docs.
private final class _TaskBox: @unchecked Sendable {
    private let wrapped: URLSessionTask
    init(_ task: URLSessionTask) { wrapped = task }
    func cancel() { wrapped.cancel() }
}