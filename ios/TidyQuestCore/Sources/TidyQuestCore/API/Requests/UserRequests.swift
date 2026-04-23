import Foundation

// MARK: - Add Kid

public struct AddKidRequest: Codable, Sendable {
    public let familyId: UUID
    public let displayName: String
    public let avatar: String
    public let color: String
    public let complexityTier: ComplexityTier
    public let birthdate: String?           // "YYYY-MM-DD"

    public init(
        familyId: UUID,
        displayName: String,
        avatar: String,
        color: String,
        complexityTier: ComplexityTier,
        birthdate: String?
    ) {
        self.familyId = familyId
        self.displayName = displayName
        self.avatar = avatar
        self.color = color
        self.complexityTier = complexityTier
        self.birthdate = birthdate
    }

    enum CodingKeys: String, CodingKey {
        case familyId       = "family_id"
        case displayName    = "display_name"
        case avatar
        case color
        case complexityTier = "complexity_tier"
        case birthdate
    }
}

// MARK: - Pair Device

public struct PairDeviceRequest: Codable, Sendable {
    public let kidUserId: UUID

    public init(kidUserId: UUID) {
        self.kidUserId = kidUserId
    }

    enum CodingKeys: String, CodingKey {
        case kidUserId = "kid_user_id"
    }
}

public struct PairingCode: Codable, Sendable {
    public let code: String
    public let expiresAt: Date

    public init(code: String, expiresAt: Date) {
        self.code = code
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case code
        case expiresAt = "expires_at"
    }
}

// MARK: - Claim Pairing

public struct ClaimPairingRequest: Codable, Sendable {
    public let pairingCode: String
    public let appBundle: String

    public init(pairingCode: String, appBundle: String) {
        self.pairingCode = pairingCode
        self.appBundle = appBundle
    }

    enum CodingKeys: String, CodingKey {
        case pairingCode = "pairing_code"
        case appBundle   = "app_bundle"
    }
}

public struct DeviceClaimResult: Codable, Sendable {
    public let deviceToken: String
    public let user: AppUser

    public init(deviceToken: String, user: AppUser) {
        self.deviceToken = deviceToken
        self.user = user
    }

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case user
    }
}

// MARK: - Revoke Device

public struct RevokeDeviceRequest: Codable, Sendable {
    public let kidUserId: UUID
    public let appAttestToken: String

    public init(kidUserId: UUID, appAttestToken: String) {
        self.kidUserId = kidUserId
        self.appAttestToken = appAttestToken
    }

    enum CodingKeys: String, CodingKey {
        case kidUserId      = "kid_user_id"
        case appAttestToken = "app_attest_token"
    }
}
