// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Foundation

extension HTTPURLResponse {

    /// Returns `true` when the status code is in the 200–299 range.
    var isSuccess: Bool { (200...299).contains(statusCode) }

    /// Maps a non-success HTTP response to the appropriate ``NexioError``.
    ///
    /// - Parameter data: Response body accompanying the error.
    /// - Returns: The matching `NexioError`, or `nil` when ``isSuccess`` is `true`.
    func nexioError(data: Data) -> NexioError? {
        switch statusCode {
        case 200...299:
            return nil
        case 401:
            return .unauthorized(self)
        case 404:
            return .notFound(self)
        default:
            return .serverError(statusCode: statusCode, data: data)
        }
    }
}