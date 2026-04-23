import Foundation

// MARK: - Redemption

public struct RequestRedemptionRequest: Codable, Sendable {
    public let rewardId: UUID
    public let userId: UUID

    public init(rewardId: UUID, userId: UUID) {
        self.rewardId = rewardId
        self.userId = userId
    }

    enum CodingKeys: String, CodingKey {
        case rewardId = "reward_id"
        case userId   = "user_id"
    }
}

public struct RedemptionApprovedResponse: Codable, Sendable {
    public let redemptionRequest: RedemptionRequest
    public let transaction: PointTransaction
    public let balanceAfter: Int

    public init(redemptionRequest: RedemptionRequest, transaction: PointTransaction, balanceAfter: Int) {
        self.redemptionRequest = redemptionRequest
        self.transaction = transaction
        self.balanceAfter = balanceAfter
    }

    enum CodingKeys: String, CodingKey {
        case redemptionRequest = "redemption_request"
        case transaction
        case balanceAfter      = "balance_after"
    }
}

// MARK: - Fine

public struct IssueFineRequest: Codable, Sendable {
    public let userId: UUID
    public let amount: Int          // positive; will be negated server-side
    public let reason: String
    public let cannedReasonKey: String?
    public let appAttestToken: String

    public init(
        userId: UUID,
        amount: Int,
        reason: String,
        cannedReasonKey: String? = nil,
        appAttestToken: String
    ) {
        self.userId = userId
        self.amount = amount
        self.reason = reason
        self.cannedReasonKey = cannedReasonKey
        self.appAttestToken = appAttestToken
    }

    enum CodingKeys: String, CodingKey {
        case userId          = "user_id"
        case amount
        case reason
        case cannedReasonKey = "canned_reason_key"
        case appAttestToken  = "app_attest_token"
    }
}

public struct FineResponse: Codable, Sendable {
    public let transaction: PointTransaction
    public let balanceAfter: Int

    public init(transaction: PointTransaction, balanceAfter: Int) {
        self.transaction = transaction
        self.balanceAfter = balanceAfter
    }

    enum CodingKeys: String, CodingKey {
        case transaction
        case balanceAfter = "balance_after"
    }
}

// MARK: - Reverse Transaction

public struct ReverseTransactionRequest: Codable, Sendable {
    public let transactionId: UUID
    public let reason: String
    public let appAttestToken: String

    public init(transactionId: UUID, reason: String, appAttestToken: String) {
        self.transactionId = transactionId
        self.reason = reason
        self.appAttestToken = appAttestToken
    }

    enum CodingKeys: String, CodingKey {
        case transactionId  = "transaction_id"
        case reason
        case appAttestToken = "app_attest_token"
    }
}
