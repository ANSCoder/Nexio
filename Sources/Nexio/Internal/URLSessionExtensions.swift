import Foundation

extension URLSession {

    /// Performs a data task and maps common `NSError` codes to ``NexioError``.
    ///
    /// - Parameter request: The URL request to execute.
    /// - Returns: Raw response data and the HTTP response.
    /// - Throws: ``NexioError`` on network failure or non-2xx status.
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
