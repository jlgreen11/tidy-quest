import Foundation
import SwiftData

@available(iOS 17, macOS 14, *)
@Model
public final class ChoreTemplateModel {
    @Attribute(.unique) public var id: UUID
    public var familyId: UUID
    public var name: String
    public var icon: String
    public var templateDescription: String?
    public var typeRaw: String
    public var scheduleData: Data
    public var targetUserIdsData: Data
    public var basePoints: Int
    public var cutoffTime: String?
    public var requiresPhoto: Bool
    public var requiresApproval: Bool
    public var onMissRaw: String
    public var onMissAmount: Int
    public var active: Bool
    public var createdAt: Date
    public var archivedAt: Date?

    @Relationship(deleteRule: .cascade) public var instances: [ChoreInstanceModel]

    public init(from domain: ChoreTemplate) {
        self.id = domain.id
        self.familyId = domain.familyId
        self.name = domain.name
        self.icon = domain.icon
        self.templateDescription = domain.description
        self.typeRaw = domain.type.rawValue
        self.scheduleData = (try? JSONEncoder().encode(domain.schedule)) ?? Data()
        self.targetUserIdsData = (try? JSONEncoder().encode(domain.targetUserIds)) ?? Data()
        self.basePoints = domain.basePoints
        self.cutoffTime = domain.cutoffTime
        self.requiresPhoto = domain.requiresPhoto
        self.requiresApproval = domain.requiresApproval
        self.onMissRaw = domain.onMiss.rawValue
        self.onMissAmount = domain.onMissAmount
        self.active = domain.active
        self.createdAt = domain.createdAt
        self.archivedAt = domain.archivedAt
        self.instances = []
    }

    public var domain: ChoreTemplate {
        let schedule = (try? JSONDecoder().decode([String: AnyCodable].self, from: scheduleData)) ?? [:]
        let targetUserIds = (try? JSONDecoder().decode([UUID].self, from: targetUserIdsData)) ?? []
        return ChoreTemplate(
            id: id,
            familyId: familyId,
            name: name,
            icon: icon,
            description: templateDescription,
            type: ChoreType(rawValue: typeRaw) ?? .daily,
            schedule: schedule,
            targetUserIds: targetUserIds,
            basePoints: basePoints,
            cutoffTime: cutoffTime,
            requiresPhoto: requiresPhoto,
            requiresApproval: requiresApproval,
            onMiss: OnMissPolicy(rawValue: onMissRaw) ?? .decay,
            onMissAmount: onMissAmount,
            active: active,
            createdAt: createdAt,
            archivedAt: archivedAt
        )
    }
}
