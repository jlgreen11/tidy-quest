import Foundation
import SwiftData

@available(iOS 17, macOS 14, *)
@Model
public final class ChoreInstanceModel {
    @Attribute(.unique) public var id: UUID
    public var templateId: UUID
    public var userId: UUID
    public var scheduledFor: String
    public var windowStart: String?
    public var windowEnd: String?
    public var statusRaw: String
    public var completedAt: Date?
    public var approvedAt: Date?
    public var proofPhotoId: UUID?
    public var awardedPoints: Int?
    public var completedByDevice: String?
    public var completedAsUser: UUID?
    public var createdAt: Date

    public var template: ChoreTemplateModel?

    public init(from domain: ChoreInstance) {
        self.id = domain.id
        self.templateId = domain.templateId
        self.userId = domain.userId
        self.scheduledFor = domain.scheduledFor
        self.windowStart = domain.windowStart
        self.windowEnd = domain.windowEnd
        self.statusRaw = domain.status.rawValue
        self.completedAt = domain.completedAt
        self.approvedAt = domain.approvedAt
        self.proofPhotoId = domain.proofPhotoId
        self.awardedPoints = domain.awardedPoints
        self.completedByDevice = domain.completedByDevice
        self.completedAsUser = domain.completedAsUser
        self.createdAt = domain.createdAt
    }

    public var domain: ChoreInstance {
        ChoreInstance(
            id: id,
            templateId: templateId,
            userId: userId,
            scheduledFor: scheduledFor,
            windowStart: windowStart,
            windowEnd: windowEnd,
            status: ChoreInstanceStatus(rawValue: statusRaw) ?? .pending,
            completedAt: completedAt,
            approvedAt: approvedAt,
            proofPhotoId: proofPhotoId,
            awardedPoints: awardedPoints,
            completedByDevice: completedByDevice,
            completedAsUser: completedAsUser,
            createdAt: createdAt
        )
    }
}
