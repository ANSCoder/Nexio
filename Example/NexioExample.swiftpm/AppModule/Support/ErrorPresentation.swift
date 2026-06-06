import Foundation
import Nexio

/// Renders any thrown error as a readable string, preferring `NexioError`'s
/// `LocalizedError` description so demo screens show the typed message.
func describe(_ error: Error) -> String {
    if let nexioError = error as? NexioError {
        return nexioError.errorDescription ?? String(describing: nexioError)
    }
    return error.localizedDescription
}
