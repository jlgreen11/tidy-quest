import Testing
import Foundation
@testable import TidyQuestCore

// RepositoryTests exercises the @Observable repository classes via the MockAPIClient.
// Repositories require macOS 14 / iOS 17 for @Observable.
// We verify observable state indirectly by testing the API round-trips that repositories wrap.

@Suite("APIClient round-trips (repository layer behavior)")
struct RepositoryTests {

    // MARK: - Family lifecycle

    @Test("createFamily then updateFamily reflects name change")
    func familyCreateThenUpdate() async throws {
        let mock = MockAPIClient()
        let created = try await mock.createFamily(
            CreateFamilyRequest(name: "TestFamily", timezone: "UTC")
        )
        #expect(created.name == "TestFamily")

        let updated = try await mock.updateFamily(
            UpdateFamilyRequest(familyId: created.id, name: "TestFamily Renamed")
        )
        #expect(updated.name == "TestFamily Renamed")
        #expect(updated.id == created.id)
    }

    @Test("addKid creates child user in mock state")
    func addKidCreatesChild() async throws {
        let mock = MockAPIClient()
        let kid = try await mock.addKid(
            AddKidRequest(
                familyId: MockAPIClient.SeedID.family,
                displayName: "NewKid",
                avatar: "kid-robot",
                color: "#FF6B6B",
                complexityTier: .standard,
                birthdate: nil
            )
        )
        #expect(kid.role == .child)
        #expect(kid.displayName == "NewKid")
        #expect(kid.complexityTier == .standard)
        #expect(kid.familyId == MockAPIClient.SeedID.family)
    }

    @Test("pairDevice then claimPairing roundtrip")
    func pairDeviceRoundtrip() async throws {
        let mock = MockAPIClient()
        let code = try await mock.pairDevice(PairDeviceRequest(kidUserId: MockAPIClient.SeedID.kai))
        #expect(!code.code.isEmpty)
        // Claim it
        let result = try await mock.claimPairing(
            ClaimPairingRequest(pairingCode: code.code, appBundle: "com.test")
        )
        #expect(!result.deviceToken.isEmpty)
        #expect(result.user.role == .child)
    }

    // MARK: - Chore lifecycle

    @Test("createTemplate is persisted and updateTemplate patches it")
    func createThenUpdateTemplate() async throws {
        let mock = MockAPIClient()
        let schedule: [String: AnyCodable] = ["daysOfWeek": AnyCodable([AnyCodable(1), AnyCodable(2)])]
        let created = try await mock.createChoreTemplate(
            CreateChoreTemplateRequest(
                familyId: MockAPIClient.SeedID.family,
                name: "Test Chore",
                icon: "star",
                type: .daily,
                schedule: schedule,
                targetUserIds: [MockAPIClient.SeedID.kai],
                basePoints: 10
            )
        )
        #expect(created.name == "Test Chore")
        #expect(created.basePoints == 10)

        let updated = try await mock.updateChoreTemplate(
            UpdateChoreTemplateRequest(templateId: created.id, basePoints: 20)
        )
        #expect(updated.id == created.id)
        #expect(updated.basePoints == 20)
    }

    @Test("completeChore then approveChore transitions status correctly")
    func completeThenApprove() async throws {
        let mock = MockAPIClient()
        // Kai's homework is pending
        let instanceId = UUID(uuidString: "66666666-6666-6666-6666-666666666604")!

        let completeResponse = try await mock.completeChoreInstance(
            CompleteChoreRequest(instanceId: instanceId, completedAt: Date())
        )
        #expect(completeResponse.instance.status == .completed)

        let approved = try await mock.approveChoreInstance(instanceId)
        #expect(approved.status == .approved)
        #expect(approved.awardedPoints == 15) // templateKaiHomework.basePoints
    }

    @Test("rejectChoreInstance transitions to rejected")
    func rejectChore() async throws {
        let mock = MockAPIClient()
        // Zara's cats chore is completed and awaiting approval
        let instanceId = UUID(uuidString: "66666666-6666-6666-6666-666666666606")!
        let rejected = try await mock.rejectChoreInstance(instanceId, reason: "Incomplete")
        #expect(rejected.status == .rejected)
    }

    @Test("rejectChoreInstance missing instance throws invalidInstance")
    func rejectMissingInstance() async {
        let mock = MockAPIClient()
        let nonexistent = UUID()
        await #expect(throws: APIError.invalidInstance) {
            try await mock.rejectChoreInstance(nonexistent, reason: nil)
        }
    }

    // MARK: - Ledger lifecycle

    @Test("issueFine produces negative transaction")
    func issueFineNegative() async throws {
        let mock = MockAPIClient()
        let txn = try await mock.issueFine(
            IssueFineRequest(
                userId: MockAPIClient.SeedID.zara,
                amount: 10,
                reason: "Fought with sibling",
                appAttestToken: "mock-attest"
            )
        )
        #expect(txn.amount == -10)
        #expect(txn.kind == .fine)
        #expect(txn.reason == "Fought with sibling")
    }

    @Test("reverseTransaction produces correction entry")
    func reverseTransaction() async throws {
        let mock = MockAPIClient()
        let fine = try await mock.issueFine(
            IssueFineRequest(
                userId: MockAPIClient.SeedID.zara,
                amount: 5,
                reason: "Rude to sibling",
                appAttestToken: "mock"
            )
        )
        let reversal = try await mock.reverseTransaction(
            fine.id, reason: "Fine was unjust", appAttestToken: "mock"
        )
        #expect(reversal.amount == 5)       // negation of -5
        #expect(reversal.kind == .correction)
    }

    // MARK: - Redemption lifecycle

    @Test("requestRedemption for affordable reward succeeds")
    func requestAffordableRedemption() async throws {
        let mock = MockAPIClient()
        // Kai has 340 points; 30 min tablet costs 75
        let redemption = try await mock.requestRedemption(
            RequestRedemptionRequest(
                rewardId: MockAPIClient.SeedID.reward30MinTablet,
                userId: MockAPIClient.SeedID.kai
            )
        )
        #expect(redemption.status == .pending)
        #expect(redemption.userId == MockAPIClient.SeedID.kai)
        #expect(redemption.rewardId == MockAPIClient.SeedID.reward30MinTablet)
    }

    @Test("approveRedemption transitions to fulfilled and produces transaction")
    func approveRedemption() async throws {
        let mock = MockAPIClient()
        let req = try await mock.requestRedemption(
            RequestRedemptionRequest(
                rewardId: MockAPIClient.SeedID.reward30MinTablet,
                userId: MockAPIClient.SeedID.kai
            )
        )
        let result = try await mock.approveRedemption(req.id, appAttestToken: "mock-attest")
        #expect(result.redemptionRequest.status == .fulfilled)
        #expect(result.transaction.amount == -75)
        #expect(result.balanceAfter == 265) // 340 - 75
    }

    @Test("denyRedemption transitions to denied")
    func denyRedemption() async throws {
        let mock = MockAPIClient()
        let req = try await mock.requestRedemption(
            RequestRedemptionRequest(
                rewardId: MockAPIClient.SeedID.reward30MinTablet,
                userId: MockAPIClient.SeedID.kai
            )
        )
        let denied = try await mock.denyRedemption(req.id, reason: "Not today")
        #expect(denied.status == .denied)
        #expect(denied.notes == "Not today")
    }

    // MARK: - Subscription

    @Test("updateSubscription returns subscription for family")
    func updateSubscriptionReturns() async throws {
        let mock = MockAPIClient()
        let sub = try await mock.updateSubscription("receipt-mock")
        #expect(sub.familyId == MockAPIClient.SeedID.family)
        #expect(sub.status == .trial)
        #expect(sub.tier == .trial)
    }
}
