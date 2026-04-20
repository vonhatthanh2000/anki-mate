import Foundation

enum DatabaseError: LocalizedError {
    case open(String)
    case sqlite(String)

    var errorDescription: String? {
        switch self {
        case .open(let message), .sqlite(let message):
            return message
        }
    }
}
