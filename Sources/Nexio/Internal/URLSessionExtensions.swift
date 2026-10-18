// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

extension URLSession {

    /// Performs a data task and maps common `NSError` codes to ``NexioError``.
    ///
    /// - Parameter request: The URL request to execute.
    /// - Returns: Raw response data and the HTTP response.
    /// - Throws: ``NexioError`` on network failure, `CancellationError` if the task
///   was cancelled. Non-2xx responses are returned, not thrown, so the caller
///   can decide whether to retry.
    func nexioData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await self.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NexioError.noInternet
            case .timedOut:
                throw NexioError.timeout
            case .cancelled:
                // Cancellation is not a failure. Surface it as Swift's standard error,
                // so callers and the image view can ignore it.
                throw CancellationError()
            default:
                throw NexioError.unknown(underlying: urlError)
            }
        } catch {
            throw NexioError.unknown(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NexioError.unknown(underlying: URLError(.badServerResponse))
        }

        return (data, http)
    }
}