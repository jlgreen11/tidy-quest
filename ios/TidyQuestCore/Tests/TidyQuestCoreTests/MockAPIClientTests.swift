import Testing
import Foundation
@testable import TidyQuestCore

@Suite("MockAPIClient — Chen-Rodriguez seed data")
struct MockAPIClientTests {

    let mock = MockAPIClient()

    // MARK: - Seed shape

    @Test("Seed family has correct identity")
    func seedFamilyIdentity() {
        let family = MockAPIClient.seedFamily
        #expect(family.id == MockAPIClient.SeedID.family)
        #expect(family.name == "Chen-Rodriguez")
        #expect(family.timezone == "America/Los_Angeles")
        #expect(family.subscriptionTier == .trial)
        #expect(family.dailyDeductionCap == 50)
        #expect(family.weeklyDeductionCap == 150)
    }

    @Test("Seed has 6 users (2 parents + 4 kids)")
    func seedUserCount() {
        let users = MockAPIClient.seedUsers
        #expect(users.count == 6)
        #expect(users.filter { $0.role == .parent }.count == 2)
        #expect(users.filter { $0.role == .child }.count == 4)
    }

    @Test("Mei is a parent with advanced complexity tier")
    func meiAttributes() {
        let mei = MockAPIClient.seedUsers.first { $0.id == MockAPIClient.SeedID.mei }
        #expect(mei != nil)
        #expect(mei?.displayName == "Mei")
        #expect(mei?.role == .parent)
        #expect(mei?.complexityTier == .advanced)
    }

    @Test("Ava is a starter-tier kid")
    func avaIssStarter() {
        let ava = MockAPIClient.seedUsers.first { $0.id == MockAPIClient.SeedID.ava }
        #expect(ava?.complexityTier == .starter)
        #expect(ava?.role == .child)
    }

    @Test("Kai is a standard-tier kid")
    func kaiIsStandard() {
        let kai = MockAPIClient.seedUsers.first { $0.id == MockAPIClient.SeedID.kai }
        #expect(kai?.complexityTier == .standard)
    }

    @Test("Zara is an advanced-tier kid")
    func zaraIsAdvanced() {
        let zara = MockAPIClient.seedUsers.first { $0.id == MockAPIClient.SeedID.zara }
        #expect(zara?.complexityTier == .advanced)
    }

    @Test("Seed has 7 chore templates")
    func seedTemplateCount() {
        #expect(MockAPIClient.seedTemplates.count == 7)
    }

    @Test("Theo's feed-dog template requires photo AND approval")
    func theoFeedDogTemplate() {
        let t = MockAPIClient.seedTemplates.first { $0.id == MockAPIClient.SeedID.templateTheoFeedDog }
        #expect(t?.requiresPhoto == true)
        #expect(t?.requiresApproval == true)
    }

    @Test("Seed has 7 rewards")
    func seedRewardCount() {
        #expect(MockAPIClient.seedRewards.count == 7)
    }

    @Test("Lego kit is a saving_goal reward worth 800 points")
    func legoKitReward() {
        let r = MockAPIClient.seedRewards.first { $0.id == MockAPIClient.SeedID.rewardLegoKit }
        #expect(r?.category == .savingGoal)
        #expect(r?.price == 800)
    }

    // MARK: - API method smoke tests

    @Test("createFamily returns new family with correct name")
    func createFamilyReturnsCorrectName() async throws {
        let req = CreateFamilyRequest(
            name: "TestFamily",
            timezone: "America/New_York"
        )
        let family = try await mock.createFamily(req)
        #expect(family.name == "TestFamily")
        #expect(family.timezone == "America/New_York")
        #expect(family.subscriptionTier == .trial)
    }

    @Test("addKid returns new child user")
    func addKidReturnsChildUser() async throws {
        let req = AddKidRequest(
            familyId: MockAPIClient.SeedID.family,
            displayName: "Maya",
            avatar: "kid-robot",
            color: "#FF6B6B",
            complexityTier: .standard,
            birthdate: "2015-03-10"
        )
        let kid = try await mock.addKid(req)
        #expect(kid.role == .child)
        #expect(kid.displayName == "Maya")
        #expect(kid.complexityTier == .standard)
    }

    @Test("pairDevice returns a 6-digit pairing code")
    func pairDeviceReturnsSixDigitCode() async throws {
        let req = PairDeviceRequest(kidUserId: MockAPIClient.SeedID.kai)
        let code = try await mock.pairDevice(req)
        #expect(code.code.count == 6)
        #expect(Int(code.code) != nil)
        #expect(code.expiresAt > Date())
    }

    @Test("completeChore transitions instance to completed")
    func completeChoreTransitionsStatus() async throws {
        // Kai's homework is pending (seed id ...666604)
        let instanceId = UUID(uuidString: "66666666-6666-6666-6666-666666666604")!
        let req = CompleteChoreRequest(instanceId: instanceId, completedAt: Date())
        let response = try await mock.completeChoreInstance(req)
        #expect(response.instance.status == .completed)
        #expect(response.instance.completedAt != nil)
    }

    @Test("completeChore throws if already completed")
    func completeChoreThrowsIfAlreadyDone() async throws {
        // Ava's make-bed is already 'approved' (seed id ...666601)
        let instanceId = UUID(uuidString: "66666666-6666-6666-6666-666666666601")!
        let req = CompleteChoreRequest(instanceId: instanceId, completedAt: Date())
        await #expect(throws: APIError.choreAlreadyCompleted) {
            try await mock.completeChoreInstance(req)
        }
    }

    @Test("approveChore transitions instance to approved with points")
    func approveChoreGrantsPoints() async throws {
        // Zara's cats-fed is completed (seed id ...666606)
        let instanceId = UUID(uuidString: "66666666-6666-6666-6666-666666666606")!
        let approved = try await mock.approveChoreInstance(instanceId)
        #expect(approved.status == .approved)
        #expect(approved.awardedPoints == 8)   // templateZaraCats.basePoints
    }

    @Test("issueFine returns negative transaction")
    func issueFineReturnsNegativeTransaction() async throws {
        let req = IssueFineRequest(
            userId: MockAPIClient.SeedID.zara,
            amount: 5,
            reason: "Rude to sibling",
            appAttestToken: "mock-attest"
        )
        let txn = try await mock.issueFine(req)
        #expect(txn.amount == -5)
        #expect(txn.kind == .fine)
        #expect(txn.userId == MockAPIClient.SeedID.zara)
    }

    @Test("requestRedemption throws if insufficient balance")
    func requestRedemptionThrowsIfBalanceLow() async throws {
        // Leaderboard kit costs 800; Theo has 88 points
        let req = RequestRedemptionRequest(
            rewardId: MockAPIClient.SeedID.rewardLegoKit,
            userId: MockAPIClient.SeedID.theo
        )
        await #expect(throws: APIError.insufficientBalance) {
            try await mock.requestRedemption(req)
        }
    }

    @Test("updateSubscription returns current subscription")
    func updateSubscriptionReturnsTrial() async throws {
        let sub = try await mock.updateSubscription("mock-receipt")
        #expect(sub.status == .trial)
        #expect(sub.familyId == MockAPIClient.SeedID.family)
    }
}
