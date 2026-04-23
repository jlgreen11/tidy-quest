import SwiftUI
import TidyQuestCore

// MARK: - Draft model

/// Mutable draft accumulated across onboarding steps.
@Observable
final class CreateFamilyDraft {
    var familyName: String = ""
    var timezone: String = TimeZone.current.identifier
    var coParentContact: String = ""
    var kidName: String = ""
    var kidAge: Int = 8
    var kidAvatar: String = "kid-1"
    var kidColor: KidColor = .sky
    var kidTier: ComplexityTier = .standard
    var pairingCode: String = ""
    var selectedPack: PresetPack? = nil
    var chores: [DraftChore] = []
    var morningReminderHour: Int = 7
    var morningReminderMinute: Int = 0
    var afternoonReminderHour: Int = 15
    var afternoonReminderMinute: Int = 30
    var createdFamily: Family? = nil
    var createdKid: AppUser? = nil

    var inferredTier: ComplexityTier {
        switch kidAge {
        case ..<8:   return .starter
        case 8..<12: return .standard
        default:     return .advanced
        }
    }
}

struct DraftChore: Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var points: Int
}

enum PresetPack: String, CaseIterable, Identifiable {
    case starter57    = "Starter 5–7"
    case standard810  = "Standard 8–10"
    case standard1114 = "Standard 11–14"
    case teenCash     = "Teen Cash-Focused"

    var id: String { rawValue }

    var ageRange: String {
        switch self {
        case .starter57:    return "Ages 5–7"
        case .standard810:  return "Ages 8–10"
        case .standard1114: return "Ages 11–14"
        case .teenCash:     return "Ages 13+"
        }
    }

    var icon: String {
        switch self {
        case .starter57:    return "star.fill"
        case .standard810:  return "checkmark.seal.fill"
        case .standard1114: return "graduationcap.fill"
        case .teenCash:     return "dollarsign.circle.fill"
        }
    }

    var prefillChores: [DraftChore] {
        switch self {
        case .starter57:
            return [
                DraftChore(id: UUID(), name: "Make bed", icon: "bed.double.fill", points: 5),
                DraftChore(id: UUID(), name: "Brush teeth", icon: "heart.fill", points: 3),
                DraftChore(id: UUID(), name: "Put toys away", icon: "archivebox.fill", points: 5),
                DraftChore(id: UUID(), name: "Get dressed", icon: "tshirt.fill", points: 3),
                DraftChore(id: UUID(), name: "Eat breakfast", icon: "fork.knife", points: 2),
            ]
        case .standard810:
            return [
                DraftChore(id: UUID(), name: "Make bed", icon: "bed.double.fill", points: 5),
                DraftChore(id: UUID(), name: "Homework", icon: "book.fill", points: 15),
                DraftChore(id: UUID(), name: "Empty dishwasher", icon: "dishwasher", points: 12),
                DraftChore(id: UUID(), name: "Feed pet", icon: "pawprint.fill", points: 8),
                DraftChore(id: UUID(), name: "Tidy bedroom", icon: "house.fill", points: 10),
            ]
        case .standard1114:
            return [
                DraftChore(id: UUID(), name: "Homework", icon: "book.fill", points: 20),
                DraftChore(id: UUID(), name: "Cook one meal/wk", icon: "frying.pan.fill", points: 40),
                DraftChore(id: UUID(), name: "Laundry", icon: "washer.fill", points: 15),
                DraftChore(id: UUID(), name: "Vacuum living room", icon: "house.circle.fill", points: 12),
                DraftChore(id: UUID(), name: "Yard work", icon: "leaf.fill", points: 25),
            ]
        case .teenCash:
            return [
                DraftChore(id: UUID(), name: "Part-time chore block", icon: "briefcase.fill", points: 50),
                DraftChore(id: UUID(), name: "Cook dinner", icon: "frying.pan.fill", points: 40),
                DraftChore(id: UUID(), name: "Deep clean bathroom", icon: "shower.fill", points: 30),
                DraftChore(id: UUID(), name: "Grocery run", icon: "cart.fill", points: 35),
                DraftChore(id: UUID(), name: "Car washing", icon: "car.fill", points: 30),
            ]
        }
    }
}

// MARK: - OnboardingFlow

@available(iOS 17, *)
struct OnboardingFlow: View {

    var familyRepo: FamilyRepository
    var authController: AuthController
    var onComplete: () -> Void

    @State private var draft = CreateFamilyDraft()
    @State private var currentStep: Int = 0

    private let totalSteps: Int = 10

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    ProgressDotsView(current: currentStep, total: totalSteps)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)

                    // Step content
                    stepView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(currentStep)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Step routing

    @ViewBuilder
    private var stepView: some View {
        switch currentStep {
        case 0:
            WelcomeStep(onContinue: advance, onSignIn: { advance() })
        case 1:
            SignInAppleStep(
                authController: authController,
                familyRepo: familyRepo,
                draft: draft,
                onContinue: advance
            )
        case 2:
            CoParentInviteStep(draft: draft, onContinue: advance)
        case 3:
            AddFirstKidStep(draft: draft, onContinue: advance)
        case 4:
            PairKidDeviceStep(draft: draft, familyRepo: familyRepo, onContinue: advance)
        case 5:
            PresetPackStep(draft: draft, onContinue: advance)
        case 6:
            ReviewChoresStep(draft: draft, onContinue: advance)
        case 7:
            ReminderCadenceStep(draft: draft, onContinue: advance)
        case 8:
            SubscriptionGateStep(familyRepo: familyRepo, onContinue: advance)
        case 9:
            OnboardingCompleteStep(
                draft: draft,
                onComplete: onComplete
            )
        default:
            onboardingCompleteStep
        }
    }

    private var onboardingCompleteStep: some View {
        VStack {
            Text("All set!")
            Button("Go to Today") { onComplete() }
        }
    }

    private func advance() {
        guard currentStep < totalSteps - 1 else {
            onComplete()
            return
        }
        withAnimation {
            currentStep += 1
        }
    }
}

// MARK: - Progress dots

private struct ProgressDotsView: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { idx in
                Capsule()
                    .fill(idx == current ? Color.accentColor : Color(.systemFill))
                    .frame(width: idx == current ? 20 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

// MARK: - Preview

#Preview("OnboardingFlow") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    let auth = AuthController(
        apiClient: client,
        keychain: KeychainStore(service: "com.jlgreen11.tidyquest.parent.preview")
    )
    return OnboardingFlow(
        familyRepo: family,
        authController: auth,
        onComplete: { }
    )
}
