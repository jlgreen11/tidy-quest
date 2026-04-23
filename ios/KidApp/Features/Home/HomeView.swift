import SwiftUI
import TidyQuestCore

// MARK: - HomeView

/// Home/Today tab — the hardest UX in the app (PLAN §5.2).
///
/// Critical hierarchy:
///   - Hero = first incomplete chore tile (60% above-fold)
///   - Progress ring below hero (completed / total)
///   - Balance = small pill in nav bar (NOT hero)
///   - Active quest ribbon below hero if quest in progress
///
/// All three tier variants (Starter/Standard/Advanced) rendered here.
@MainActor
struct HomeView: View {
    let kid: AppUser
    let choreRepository: ChoreRepository
    let ledgerRepository: LedgerRepository
    /// Display name of the approving parent (for "Waiting for [parent]" labels).
    let parentName: String

    @Environment(\.tierTheme) private var tier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Local state

    @State private var showConfetti = false
    @State private var photoInstance: ChoreInstance?
    @State private var completedRoutineIds: Set<UUID> = []

    // MARK: - Derived

    private var instances: [ChoreInstance] {
        choreRepository.instances(for: kid.id)
    }

    private var pendingInstances: [ChoreInstance] {
        instances.filter { $0.status == .pending }
    }

    private var completedCount: Int {
        instances.filter { $0.status == .completed || $0.status == .approved }.count
    }

    private var totalCount: Int { instances.count }

    private var balance: Int {
        ledgerRepository.balance(for: kid.id)
    }

    private var heroInstance: ChoreInstance? {
        pendingInstances.first
    }

    private var remainingInstances: [ChoreInstance] {
        pendingInstances.dropFirst().map { $0 }
    }

    private var doneInstances: [ChoreInstance] {
        instances.filter { $0.status != .pending }
    }

    private var templates: [UUID: ChoreTemplate] {
        #if DEBUG
        // ChoreRepository.templates is only populated by mutations; there is no fetch
        // endpoint in the API protocol. In DEBUG builds fall back to MockAPIClient seed
        // templates so ChoreTile renders without modifying TidyQuestCore.
        let repoTemplates = choreRepository.templates
        let source = repoTemplates.isEmpty ? MockAPIClient.seedTemplates : repoTemplates
        return Dictionary(uniqueKeysWithValues: source.map { ($0.id, $0) })
        #else
        return Dictionary(uniqueKeysWithValues: choreRepository.templates.map { ($0.id, $0) })
        #endif
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: tier == .starter ? 20 : 16) {

                    // Progress ring or bar (tier-dependent)
                    progressSection
                        .padding(.horizontal, 16)

                    // Hero tile
                    if let hero = heroInstance,
                       let template = templates[hero.templateId] {
                        heroSection(instance: hero, template: template)
                            .padding(.horizontal, 16)
                    } else {
                        allDoneView
                            .padding(.horizontal, 16)
                    }

                    // Quest ribbon placeholder (C4 Wave B fills this)
                    // ESCALATE: Active quest model not yet available in Core; ribbon is a stub.
                    // questRibbon

                    // Remaining chores
                    if !remainingInstances.isEmpty {
                        remainingSection
                            .padding(.horizontal, 16)
                    }

                    // Completed chores (collapsed by default on Starter)
                    if !doneInstances.isEmpty && tier != .starter {
                        completedSection
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    balancePill
                }
            }
            .overlay(alignment: .center) {
                ConfettiView(isActive: $showConfetti)
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $photoInstance) { inst in
            if let template = templates[inst.templateId] {
                PhotoProofCaptureView(
                    instance: inst,
                    template: template,
                    onPhotoUploaded: { photoId in
                        Task { await completeWithPhoto(instance: inst, photoId: photoId) }
                    },
                    isPresented: Binding(
                        get: { photoInstance != nil },
                        set: { if !$0 { photoInstance = nil } }
                    )
                )
            }
        }
        .task {
            // Register realtime scope
            choreRepository.loadSeedInstances(choreRepository.instances(for: kid.id))
        }
    }

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning!"
        case 12..<17: return "Good afternoon!"
        default: return "Good evening!"
        }
    }

    // MARK: - Balance pill (nav bar — NOT hero per PLAN §5.2)

    @ViewBuilder
    private var balancePill: some View {
        if tier.showNumericBalance {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("\(balance)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: balance)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .accessibilityLabel("\(balance) points")
        } else {
            // Starter: jar metaphor in nav bar (compact)
            JarProgressView(
                balance: balance,
                kidColor: Color(hex: kid.color) ?? .accentColor
            )
            .scaleEffect(0.55)
            .frame(width: 60, height: 44)
        }
    }

    // MARK: - Progress section (ring for Starter/Standard, bar for Advanced)

    @ViewBuilder
    private var progressSection: some View {
        HStack(spacing: 16) {
            if tier == .advanced {
                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Today's progress")
                            .font(tier.captionFont)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(completedCount)/\(totalCount)")
                            .font(tier.captionFont)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)
                            Capsule().fill(Color.green)
                                .frame(
                                    width: totalCount > 0
                                        ? geo.size.width * CGFloat(completedCount) / CGFloat(totalCount)
                                        : 0,
                                    height: 8
                                )
                                .animation(reduceMotion ? nil : .spring(duration: 0.5), value: completedCount)
                        }
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Progress: \(completedCount) of \(totalCount) chores done")
            } else {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: totalCount > 0 ? CGFloat(completedCount) / CGFloat(totalCount) : 0)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .spring(duration: 0.6), value: completedCount)
                }
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedCount) of \(totalCount) done")
                        .font(tier.bodyFont)
                        .foregroundStyle(.primary)
                    if pendingInstances.isEmpty && totalCount > 0 {
                        Text("All done!")
                            .font(tier.captionFont)
                            .foregroundStyle(.green)
                    } else if !pendingInstances.isEmpty {
                        Text("\(pendingInstances.count) left")
                            .font(tier.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(completedCount) of \(totalCount) chores done")

                Spacer()
            }
        }
    }

    // MARK: - Hero section

    private func heroSection(instance: ChoreInstance, template: ChoreTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tier == .starter ? "What's next?" : "Do this first")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            ChoreTile(
                instance: instance,
                template: template,
                streakCount: choreRepository.currentStreak(userId: kid.id, templateId: template.id),
                parentName: parentName,
                onComplete: { inst in
                    Task { await handleComplete(instance: inst) }
                },
                onPhotoRequired: { inst in
                    photoInstance = inst
                }
            )
            // Hero tile occupies ~60% of above-fold area:
            // On a standard screen (~700pt visible), 60% = ~420pt.
            // We set minHeight proportional to tier's tap target, with generous sizing.
            .frame(minHeight: tier == .starter ? 180 : (tier == .standard ? 150 : 120))
        }
    }

    // MARK: - All done view

    @ViewBuilder private var allDoneIcon: some View {
        let base = Image(systemName: "checkmark.seal.fill")
            .font(.system(size: tier == .starter ? 72 : 52))
            .foregroundStyle(.green)
        if #available(iOS 18.0, *) {
            base.symbolEffect(.bounce)
        } else {
            base
        }
    }

    private var allDoneView: some View {
        VStack(spacing: 12) {
            allDoneIcon

            Text("All done today!")
                .font(tier.headlineFont)
                .foregroundStyle(.primary)

            Text("Great work, \(kid.displayName)!")
                .font(tier.bodyFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: tier.tileCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All done today! Great work, \(kid.displayName)!")
    }

    // MARK: - Remaining section

    @ViewBuilder
    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Also today")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)

            ForEach(remainingInstances) { inst in
                if let template = templates[inst.templateId] {
                    ChoreTile(
                        instance: inst,
                        template: template,
                        streakCount: choreRepository.currentStreak(userId: kid.id, templateId: template.id),
                        parentName: parentName,
                        onComplete: { i in Task { await handleComplete(instance: i) } },
                        onPhotoRequired: { i in photoInstance = i }
                    )
                }
            }
        }
    }

    // MARK: - Completed section

    @ViewBuilder
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Completed")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)

            ForEach(doneInstances) { inst in
                if let template = templates[inst.templateId] {
                    ChoreTile(
                        instance: inst,
                        template: template,
                        streakCount: 0,
                        parentName: parentName,
                        onComplete: { _ in },    // no-op: already done
                        onPhotoRequired: { _ in }
                    )
                    .disabled(true)
                    .opacity(tier == .advanced ? 0.6 : 0.8)
                }
            }
        }
    }

    // MARK: - Complete handler

    private func handleComplete(instance: ChoreInstance) async {
        guard let template = templates[instance.templateId] else { return }

        let req = CompleteChoreRequest(
            instanceId: instance.id,
            completedAt: Date(),
            proofPhotoId: nil,
            completedByDevice: nil
        )
        do {
            let response = try await choreRepository.completeChore(req)
            if let balance = response.balanceAfter {
                ledgerRepository.setBalance(balance, for: kid.id)
            }

            // Routine completion check: if this was the last pending instance, fire celebration
            let remaining = choreRepository.instances(for: kid.id).filter { $0.status == .pending }
            if remaining.isEmpty && totalCount > 0 {
                HapticFeedback.routineComplete(tier: tier)
                if reduceMotion {
                    // Subtle: no confetti
                } else {
                    showConfetti = true
                }
            }
        } catch {
            // Error handled by repository; tile stays in pending state
        }
    }

    private func completeWithPhoto(instance: ChoreInstance, photoId: UUID) async {
        let req = CompleteChoreRequest(
            instanceId: instance.id,
            completedAt: Date(),
            proofPhotoId: photoId,
            completedByDevice: nil
        )
        do {
            _ = try await choreRepository.completeChore(req)
        } catch {
            // Error visible via choreRepository.error
        }
    }
}

// MARK: - Preview
// MARK: - Preview helpers (file-private)

private func makeSeedInstances(for userId: UUID) -> [ChoreInstance] {
    let today = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return f.string(from: Date())
    }()
    let templates = MockAPIClient.seedTemplates.filter { $0.targetUserIds.contains(userId) }
    return templates.enumerated().map { idx, t in
        ChoreInstance(
            id: UUID(),
            templateId: t.id,
            userId: userId,
            scheduledFor: today,
            windowStart: nil, windowEnd: nil,
            status: idx == 0 ? .approved : .pending,
            completedAt: idx == 0 ? Date().addingTimeInterval(-3600) : nil,
            approvedAt: idx == 0 ? Date().addingTimeInterval(-3600) : nil,
            proofPhotoId: nil,
            awardedPoints: idx == 0 ? t.basePoints : nil,
            completedByDevice: nil,
            completedAsUser: nil,
            createdAt: Date()
        )
    }
}

#Preview("HomeView — Standard") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .standard })!
    chore.loadSeedInstances(makeSeedInstances(for: kid.id))
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return HomeView(kid: kid, choreRepository: chore, ledgerRepository: ledger, parentName: "Mom")
        .tierTheme(kid.complexityTier.tier)
}

#Preview("HomeView — Starter") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .starter })!
    chore.loadSeedInstances(makeSeedInstances(for: kid.id))
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return HomeView(kid: kid, choreRepository: chore, ledgerRepository: ledger, parentName: "Mom")
        .tierTheme(.starter)
}

#Preview("HomeView — Advanced") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .advanced && $0.role == .child })!
    chore.loadSeedInstances(makeSeedInstances(for: kid.id))
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return HomeView(kid: kid, choreRepository: chore, ledgerRepository: ledger, parentName: "Dad")
        .tierTheme(.advanced)
}
