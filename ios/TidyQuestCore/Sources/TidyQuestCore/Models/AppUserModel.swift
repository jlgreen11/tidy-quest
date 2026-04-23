import Foundation
import SwiftData

@available(iOS 17, macOS 14, *)
@Model
public final class AppUserModel {
    @Attribute(.unique) public var id: UUID
    public var familyId: UUID?
    public var roleRaw: String
    public var displayName: String
    public var avatar: String
    public var color: String
    public var complexityTierRaw: String
    public var birthdate: String?
    public var appleSub: String?
    public var devicePairingCode: String?
    public var devicePairingExpiresAt: Date?
    public var cachedBalance: Int
    public var cachedBalanceAsOfTxnId: UUID?
    public var createdAt: Date
    public var deletedAt: Date?

    public var family: FamilyModel?

    public init(from domain: AppUser) {
        self.id = domain.id
        self.familyId = domain.familyId
        self.roleRaw = domain.role.rawValue
        self.displayName = domain.displayName
        self.avatar = domain.avatar
        self.color = domain.color
        self.complexityTierRaw = domain.complexityTier.rawValue
        self.birthdate = domain.birthdate
        self.appleSub = domain.appleSub
        self.devicePairingCode = domain.devicePairingCode
        self.devicePairingExpiresAt = domain.devicePairingExpiresAt
        self.cachedBalance = domain.cachedBalance
        self.cachedBalanceAsOfTxnId = domain.cachedBalanceAsOfTxnId
        self.createdAt = domain.createdAt
        self.deletedAt = domain.deletedAt
    }

    public var domain: AppUser {
        AppUser(
            id: id,
            familyId: familyId,
            role: UserRole(rawValue: roleRaw) ?? .observer,
            displayName: displayName,
            avatar: avatar,
            color: color,
            complexityTier: ComplexityTier(rawValue: complexityTierRaw) ?? .standard,
            birthdate: birthdate,
            appleSub: appleSub,
            devicePairingCode: devicePairingCode,
            devicePairingExpiresAt: devicePairingExpiresAt,
            cachedBalance: cachedBalance,
            cachedBalanceAsOfTxnId: cachedBalanceAsOfTxnId,
            createdAt: createdAt,
            deletedAt: deletedAt
        )
    }
}
