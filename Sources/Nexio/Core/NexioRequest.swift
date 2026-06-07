// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

/// A handle to an in-flight Nexio request.
///
/// Retain the handle if you need to cancel the request before it completes.
///
/// ```swift
/// let handle = NexioRequest()
/// Task {
///     let users: [User] = try await NexioClient.shared.get("/users", requestHandle: handle)
/// }
/// // Later:
/// handle.cancel()
/// ```
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