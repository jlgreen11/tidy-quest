import SwiftUI
import TidyQuestCore

/// Onboarding Step 9 — Subscription gate: 14-day trial, then $5.99/mo or $39.99/yr.
@available(iOS 17, *)
struct SubscriptionGateStep: View {

    var apiClient: any APIClient
    let onContinue: () -> Void

    @State private var isPurchasing: Bool = false
    @State private var selectedProduct: ProductOption? = nil
    @State private var errorMessage: String? = nil
    @State private var showAlert: Bool = false

    enum ProductOption: String, CaseIterable, Identifiable {
        case monthly = "com.jlgreen11.tidyquest.monthly"
        case yearly  = "com.jlgreen11.tidyquest.yearly"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .monthly: return "$5.99 / month"
            case .yearly:  return "$39.99 / year — save 44%"
            }
        }
        var badge: String? {
            switch self {
            case .monthly: return nil
            case .yearly:  return "Best value"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    Text("Your 14-day free trial starts now")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                        .accessibilityAddTraits(.isHeader)

                    Text("No charge today. Cancel anytime before your trial ends. After 14 days, choose a plan to keep the full experience.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // What's included
                VStack(alignment: .leading, spacing: 10) {
                    FeatureRow(icon: "checkmark.circle.fill", text: "Unlimited chores & rewards")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Economy dashboard & alerts")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Up to 6 kids per family")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Realtime approvals & notifications")
                }
                .padding(.horizontal, 24)

                // Product options
                VStack(spacing: 12) {
                    ForEach(ProductOption.allCases) { product in
                        ProductCard(
                            product: product,
                            isSelected: selectedProduct == product,
                            onSelect: { selectedProduct = product }
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Primary CTA
                Button {
                    Task { await startTrial() }
                } label: {
                    HStack {
                        Spacer()
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Start free trial")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPurchasing)
                .padding(.horizontal, 24)
                .accessibilityLabel("Start 14-day free trial")

                // Skip
                Button("Skip — decide later", action: onContinue)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .disabled(isPurchasing)
                    .padding(.bottom, 40)
                    .accessibilityLabel("Skip subscription for now and decide later")

                Text("Subscriptions auto-renew. Cancel in App Store Settings at any time.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
        .alert("Trial Activation Failed", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred.")
        }
    }

    // MARK: - Helpers

    private func startTrial() async {
        isPurchasing = true
        defer { isPurchasing = false }

        // TODO (v0.2): wire real StoreKit 2 Product.purchase() and pass the
        // decoded JWS receipt. For v0.1 we send a trial-mock payload that
        // matches the backend's `StoreKit2ReceiptSchema`. The mock edge function
        // accepts any payload with transactionId + productId.
        let productId = (selectedProduct ?? .monthly).rawValue
        let receipt = StoreKit2Receipt(
            payloadType: "storekit2-receipt",
            transactionId: "mock-trial-\(UUID().uuidString)",
            productId: productId,
            purchaseDate: ISO8601DateFormatter().string(from: Date()),
            expiresDate: nil,
            environment: "Sandbox"
        )
        do {
            _ = try await apiClient.updateSubscription(receipt)
            onContinue()
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Product card

private struct ProductCard: View {
    let product: SubscriptionGateStep.ProductOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let badge = product.badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(product.displayName)\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview("SubscriptionGateStep") {
    let client = MockAPIClient()
    return SubscriptionGateStep(apiClient: client, onContinue: { })
}
