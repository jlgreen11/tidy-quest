import Foundation

/// Mirrors the `app_user` Postgres table.
public struct AppUser: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID?
    public let role: UserRole
    public let displayName: String
    public let avatar: String
    public let color: String
    public let complexityTier: ComplexityTier
    public let birthdate: String?             // Postgres `date` as "YYYY-MM-DD"
    public let appleSub: String?
    public let devicePairingCode: String?
    public let devicePairingExpiresAt: Date?
    public let cachedBalance: Int
    public let cachedBalanceAsOfTxnId: UUID?
    public let createdAt: Date
    public let deletedAt: Date?

    public init(
        id: UUID,
        familyId: UUID?,
        role: UserRole,
        displayName: String,
        avatar: String,
        color: String,
        complexityTier: ComplexityTier,
        birthdate: String?,
        appleSub: String?,
        devicePairingCode: String?,
        devicePairingExpiresAt: Date?,
        cachedBalance: Int,
        cachedBalanceAsOfTxnId: UUID?,
        createdAt: Date,
        deletedAt: Date?
    ) {
        self.id = id
        self.familyId = familyId
        self.role = role
        self.displayName = displayName
        self.avatar = avatar
        self.color = color
        self.complexityTier = complexityTier
        self.birthdate = birthdate
        self.appleSub = appleSub
        self.devicePairingCode = devicePairingCode
        self.devicePairingExpiresAt = devicePairingExpiresAt
        self.cachedBalance = cachedBalance
        self.cachedBalanceAsOfTxnId = cachedBalanceAsOfTxnId
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId                 = "family_id"
        case role
        case displayName              = "display_name"
        case avatar
        case color
        case complexityTier           = "complexity_tier"
        case birthdate
        case appleSub                 = "apple_sub"
        case devicePairingCode        = "device_pairing_code"
        case devicePairingExpiresAt   = "device_pairing_expires_at"
        case cachedBalance            = "cached_balance"
        case cachedBalanceAsOfTxnId   = "cached_balance_as_of_txn_id"
        case createdAt                = "created_at"
        case deletedAt                = "deleted_at"
    }
}
