import Foundation

/// Mirrors the `subscription` Postgres table (one row per family).
public struct Subscription: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID
    public let storeTransactionId: String?
    public let productId: String?
    public let tier: SubscriptionTier
    public let purchasedAt: Date?
    public let expiresAt: Date?
    public let status: SubscriptionStatus
    public let receiptHash: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        familyId: UUID,
        storeTransactionId: String?,
        productId: String?,
        tier: SubscriptionTier,
        purchasedAt: Date?,
        expiresAt: Date?,
        status: SubscriptionStatus,
        receiptHash: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.familyId = familyId
        self.storeTransactionId = storeTransactionId
        self.productId = productId
        self.tier = tier
        self.purchasedAt = purchasedAt
        self.expiresAt = expiresAt
        self.status = status
        self.receiptHash = receiptHash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId           = "family_id"
        case storeTransactionId = "store_transaction_id"
        case productId          = "product_id"
        case tier
        case purchasedAt        = "purchased_at"
        case expiresAt          = "expires_at"
        case status
        case receiptHash        = "receipt_hash"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }
}
