import Foundation
import SwiftData

@available(iOS 17, macOS 14, *)
@Model
public final class RewardModel {
    @Attribute(.unique) public var id: UUID
    public var familyId: UUID
    public var name: String
    public var icon: String
    public var categoryRaw: String
    public var price: Int
    public var cooldown: Int?
    public var autoApproveUnder: Int?
    public var active: Bool
    public var createdAt: Date
    public var archivedAt: Date?

    public init(from domain: Reward) {
        self.id = domain.id
        self.familyId = domain.familyId
        self.name = domain.name
        self.icon = domain.icon
        self.categoryRaw = domain.category.rawValue
        self.price = domain.price
        self.cooldown = domain.cooldown
        self.autoApproveUnder = domain.autoApproveUnder
        self.active = domain.active
        self.createdAt = domain.createdAt
        self.archivedAt = domain.archivedAt
    }

    public var domain: Reward {
        Reward(
            id: id,
            familyId: familyId,
            name: name,
            icon: icon,
            category: RewardCategory(rawValue: categoryRaw) ?? .other,
            price: price,
            cooldown: cooldown,
            autoApproveUnder: autoApproveUnder,
            active: active,
            createdAt: createdAt,
            archivedAt: archivedAt
        )
    }
}
