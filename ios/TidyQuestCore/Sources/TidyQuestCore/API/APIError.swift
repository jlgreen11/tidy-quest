import Foundation

/// Structured errors returned by TidyQuest edge functions.
/// Maps to the `{ error: { code, message, details? } }` response envelope.
public enum APIError: Error, Sendable, Equatable, LocalizedError {
    // Chore errors
    case choreAlreadyCompleted
    case outsideWindow
    case invalidInstance
    // Redemption errors
    case insufficientBalance
    case rewardUnavailable
    case cooldownActive
    // Rate limiting
    case rateLimitExceeded
    // Deduction caps
    case dailyDeductionCapExceeded
    case weeklyDeductionCapExceeded
    // Auth / security
    case unauthorized
    case forbidden
    case appAttestRequired
    case appAttestInvalid
    // Generic
    case invalidInput(String)
    case notFound
    case conflict
    case internalError(String)
    // Network/decoding (string messages for Equatable/Sendable compatibility)
    case networkError(String)
    case decodingError(String)
    case unknown(code: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .choreAlreadyCompleted:       "This chore has already been completed."
        case .outsideWindow:               "Outside the allowed completion window."
        case .invalidInstance:             "Invalid chore instance."
        case .insufficientBalance:         "Insufficient point balance."
        case .rewardUnavailable:           "This reward is no longer available."
        case .cooldownActive:              "This reward is on cooldown."
        case .rateLimitExceeded:           "Too many requests. Please slow down."
        case .dailyDeductionCapExceeded:   "Daily deduction cap reached."
        case .weeklyDeductionCapExceeded:  "Weekly deduction cap reached."
        case .unauthorized:                "Authentication required."
        case .forbidden:                   "You don't have permission for this action."
        case .appAttestRequired:           "App attestation required."
        case .appAttestInvalid:            "App attestation invalid."
        case .invalidInput(let msg):       "Invalid input: \(msg)"
        case .notFound:                    "Resource not found."
        case .conflict:                    "Conflict with existing data."
        case .internalError(let msg):      "Server error: \(msg)"
        case .networkError(let msg):       "Network error: \(msg)"
        case .decodingError(let msg):      "Response parsing error: \(msg)"
        case .unknown(let code, let msg):  "[\(code)] \(msg)"
        }
    }

    /// Parse a raw edge function error code string into an `APIError`.
    public static func from(code: String, message: String) -> APIError {
        switch code {
        case "CHORE_ALREADY_COMPLETED":       .choreAlreadyCompleted
        case "OUTSIDE_WINDOW":                .outsideWindow
        case "INVALID_INSTANCE":              .invalidInstance
        case "INSUFFICIENT_BALANCE":          .insufficientBalance
        case "REWARD_UNAVAILABLE":            .rewardUnavailable
        case "COOLDOWN_ACTIVE":               .cooldownActive
        case "RATE_LIMIT_EXCEEDED":           .rateLimitExceeded
        case "DAILY_DEDUCTION_CAP_EXCEEDED":  .dailyDeductionCapExceeded
        case "WEEKLY_DEDUCTION_CAP_EXCEEDED": .weeklyDeductionCapExceeded
        case "UNAUTHORIZED":                  .unauthorized
        case "FORBIDDEN":                     .forbidden
        case "APP_ATTEST_REQUIRED":           .appAttestRequired
        case "APP_ATTEST_INVALID":            .appAttestInvalid
        case "INVALID_INPUT":                 .invalidInput(message)
        case "NOT_FOUND":                     .notFound
        case "CONFLICT":                      .conflict
        case "INTERNAL_ERROR":                .internalError(message)
        default:                              .unknown(code: code, message: message)
        }
    }
}

// MARK: - Edge error envelope

private struct EdgeErrorEnvelope: Decodable {
    struct Payload: Decodable {
        let code: String
        let message: String
    }
    let error: Payload
}

extension APIError {
    /// Attempt to parse `data` as an edge function error envelope.
    /// Returns nil if the data is not an error response.
    static func parseEdgeError(from data: Data) -> APIError? {
        guard let envelope = try? JSONDecoder().decode(EdgeErrorEnvelope.self, from: data) else {
            return nil
        }
        return .from(code: envelope.error.code, message: envelope.error.message)
    }
}
