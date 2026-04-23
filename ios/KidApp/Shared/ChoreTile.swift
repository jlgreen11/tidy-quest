import SwiftUI
import TidyQuestCore

// MARK: - ChoreTile

/// The central tile used on the Home screen.
/// Handles all states (pending, completed, approved, rejected, missed, pending-approval, requires-photo).
/// All tier variants handled via @Environment(\.tierTheme).
///
/// Asset naming convention (Starter tier illustrated icons):
///   "starter-icon-<template.icon>" where template.icon is the SF Symbol name with dots replaced by dashes.
///   Example: "bed.double.fill" → "starter-icon-bed-double-fill"
///   These are placeholder references — the asset catalog stubs will be filled in by the design team.
struct ChoreTile: View {
    let instance: ChoreInstance
    let template: ChoreTemplate
    /// Current streak for this chore (0 = no streak).
    let streakCount: Int
    /// Display name of the parent for "Waiting for [parent]" state.
    let parentName: String
    /// Called when the tile is tapped with intent to complete.
    let onComplete: (ChoreInstance) -> Void
    /// Called when the tile is tapped and requires_photo = true.
    let onPhotoRequired: (ChoreInstance) -> Void

    @Environment(\.tierTheme) private var tier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Local state

    @State private var isFlipped = false
    @State private var showPointsBadge = false
    @State private var pointsBadgeOffset: CGFloat = 0
    @State private var pointsBadgeOpacity: Double = 1
    @State private var isJiggling = false
    @State private var showAlreadyDoneTooltip = false

    // MARK: - Computed

    private var isCompleted: Bool {
        instance.status == .completed || instance.status == .approved
    }
    private var isPendingApproval: Bool {
        instance.status == .completed && template.requiresApproval
    }
    private var isMissed: Bool { instance.status == .missed }
    private var isRejected: Bool { instance.status == .rejected }

    private var tileColor: Color {
        if isMissed    { return .gray }
        if isRejected  { return .red.opacity(0.7) }
        if isCompleted { return .green }
        return Color(hex: "4D96FF") // sky blue — default pending
    }

    private var minSize: CGFloat { tier.minTapTarget }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Front face
            tileContent
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)

            // Back face (checkmark)
            if isFlipped {
                completedFace
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            }

            // "+N" floating badge
            if showPointsBadge {
                pointsBadgeView
                    .offset(y: pointsBadgeOffset)
                    .opacity(pointsBadgeOpacity)
                    .allowsHitTesting(false)
            }

            // "Already done!" tooltip
            if showAlreadyDoneTooltip {
                alreadyDoneTooltip
            }
        }
        .frame(minWidth: minSize, minHeight: minSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isCompleted ? .isStaticText : .isButton)
    }

    // MARK: - Tile content (front face)

    @ViewBuilder
    private var tileContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: tier == .starter ? 12 : 8) {
                choreIcon

                Text(template.name)
                    .font(tier.headlineFont)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                pointsRow

                if isPendingApproval {
                    pendingApprovalLabel
                }
            }
            .padding(tier == .starter ? 20 : 14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                    .fill(tileBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                            .stroke(tileBorderColor, lineWidth: isCompleted ? 2 : 1)
                    }
            }
            .rotationEffect(.degrees(isJiggling ? 2 : 0))
            .animation(
                isJiggling ? .easeInOut(duration: 0.05).repeatCount(4, autoreverses: true) : .default,
                value: isJiggling
            )

            // Streak badge — Standard/Advanced only
            if tier != .starter && streakCount > 1 && !isCompleted {
                StreakBadge(count: streakCount)
                    .offset(x: 8, y: -8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .onLongPressGesture(minimumDuration: 0.5) {
            if tier == .starter { playVoiceLabel() }
        }
    }

    // MARK: - Completed face

    private var completedFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                .fill(Color.green.opacity(0.15))
                .overlay {
                    RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: tier == .starter ? 48 : 36))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .speed(1.2))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minSize)
        .padding(tier == .starter ? 20 : 14)
    }

    // MARK: - Icon

    @ViewBuilder
    private var choreIcon: some View {
        if tier.useIllustratedIcons {
            // Starter: illustrated image from asset catalog
            // Asset name: "starter-icon-<template.icon>" (dots replaced by dashes)
            let assetName = "starter-icon-\(template.icon.replacingOccurrences(of: ".", with: "-"))"
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                // Fallback to SF Symbol if asset not yet in catalog
                .overlay {
                    if UIImage(named: assetName) == nil {
                        Image(systemName: template.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: "4D96FF"))
                    }
                }
        } else {
            let iconColor: Color = tier == .advanced
                ? Color(hex: template.icon.isEmpty ? "6C757D" : "6C757D").opacity(0.7)
                : Color(hex: "4D96FF")

            Image(systemName: template.icon)
                .font(.system(size: tier == .standard ? 32 : 26))
                .foregroundStyle(tier == .advanced ? .secondary : iconColor)
                .symbolRenderingMode(tier == .advanced ? .monochrome : .multicolor)
        }
    }

    // MARK: - Points row

    @ViewBuilder
    private var pointsRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text("+\(template.basePoints) pts")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Pending approval label

    private var pendingApprovalLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            Text("Waiting for \(parentName)")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.yellow.opacity(0.12), in: Capsule())
    }

    // MARK: - "+N" badge

    private var pointsBadgeView: some View {
        Text("+\(template.basePoints)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.green)
            .shadow(color: .black.opacity(0.15), radius: 2)
    }

    // MARK: - "Already done!" tooltip

    private var alreadyDoneTooltip: some View {
        Text("Already done!")
            .font(tier.captionFont)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    withAnimation { showAlreadyDoneTooltip = false }
                }
            }
    }

    // MARK: - Tile backgrounds

    private var tileBackground: Color {
        if isCompleted {
            return .green.opacity(colorScheme == .dark ? 0.12 : 0.08)
        }
        if isMissed { return .gray.opacity(0.08) }
        if isRejected { return .red.opacity(0.08) }
        return colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }

    private var tileBorderColor: Color {
        if isCompleted { return .green.opacity(0.4) }
        if isMissed    { return .gray.opacity(0.2) }
        if isRejected  { return .red.opacity(0.3) }
        return Color.secondary.opacity(0.15)
    }

    // MARK: - Interaction handlers

    private func handleTap() {
        guard !isMissed else { return }

        if isCompleted {
            // Double-tap guard: soft error haptic + jiggle + tooltip
            HapticFeedback.error()
            if !isJiggling {
                isJiggling = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    isJiggling = false
                }
            }
            withAnimation { showAlreadyDoneTooltip = true }
            return
        }

        // Needs photo first?
        if template.requiresPhoto {
            onPhotoRequired(instance)
            return
        }

        // Standard complete flow
        Task { @MainActor in
            HapticFeedback.choreComplete(tier: tier)
            await completeWithAnimation()
            onComplete(instance)
        }
    }

    @MainActor
    private func completeWithAnimation() async {
        // Flip tile
        if !reduceMotion {
            withAnimation(.spring(duration: 0.3)) { isFlipped = true }
        }

        // Float "+N" badge
        showPointsBadge = true
        pointsBadgeOffset = 0
        pointsBadgeOpacity = 1

        if reduceMotion {
            // Just fade
            withAnimation(.easeOut(duration: 0.5)) { pointsBadgeOpacity = 0 }
            try? await Task.sleep(for: .milliseconds(500))
        } else {
            withAnimation(.easeOut(duration: 0.8)) {
                pointsBadgeOffset = -40
                pointsBadgeOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(800))
        }
        showPointsBadge = false
    }

    // MARK: - Voice playback (Starter tier long-press)

    private func playVoiceLabel() {
        // Uses AVSpeechSynthesizer to read chore name aloud.
        // Implementation delegates to a shared speech manager to avoid AVAudioSession conflicts.
        SpeechSynthesizer.shared.speak(template.name)
    }

    // MARK: - Accessibility

    private var voiceOverLabel: String {
        var parts = [template.name, "\(template.basePoints) points"]
        switch instance.status {
        case .pending:
            parts.append(template.requiresApproval ? "requires approval" : "pending")
        case .completed:
            parts.append(template.requiresApproval ? "waiting for approval" : "completed")
        case .approved:
            parts.append("approved")
        case .rejected:
            parts.append("rejected")
        case .missed:
            parts.append("missed")
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: String {
        if isCompleted { return "Already completed" }
        if isMissed    { return "" }
        if template.requiresPhoto { return "Double-tap to take a photo and complete" }
        return "Double-tap to complete"
    }
}

// MARK: - SpeechSynthesizer (Starter tier long-press)

import AVFoundation

/// Shared speech synthesizer for Starter tier voice playback.
@MainActor
final class SpeechSynthesizer {
    static let shared = SpeechSynthesizer()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
    }
}

// MARK: - Preview
#Preview("ChoreTile — all tiers") {
    let templates = MockAPIClient.seedTemplates
    let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
    let instances: [ChoreInstance] = [
        ChoreInstance(id: UUID(), templateId: templates[0].id, userId: UUID(),
                      scheduledFor: today, windowStart: nil, windowEnd: nil,
                      status: .pending, completedAt: nil, approvedAt: nil,
                      proofPhotoId: nil, awardedPoints: nil,
                      completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
        ChoreInstance(id: UUID(), templateId: templates[1].id, userId: UUID(),
                      scheduledFor: today, windowStart: nil, windowEnd: nil,
                      status: .completed, completedAt: Date(), approvedAt: nil,
                      proofPhotoId: nil, awardedPoints: nil,
                      completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
        ChoreInstance(id: UUID(), templateId: templates[3].id, userId: UUID(),
                      scheduledFor: today, windowStart: nil, windowEnd: nil,
                      status: .completed, completedAt: Date(), approvedAt: nil,
                      proofPhotoId: nil, awardedPoints: nil,
                      completedByDevice: nil, completedAsUser: nil, createdAt: Date())
    ]

    return ScrollView {
        VStack(spacing: 16) {
            Text("Starter").font(.caption).foregroundStyle(.secondary)
            ChoreTile(instance: instances[0], template: templates[0], streakCount: 0, parentName: "Mom",
                      onComplete: { _ in }, onPhotoRequired: { _ in })
            .tierTheme(.starter)

            Text("Standard - Completed").font(.caption).foregroundStyle(.secondary)
            ChoreTile(instance: instances[1], template: templates[1], streakCount: 5, parentName: "Mom",
                      onComplete: { _ in }, onPhotoRequired: { _ in })
            .tierTheme(.standard)

            Text("Advanced - Pending Approval").font(.caption).foregroundStyle(.secondary)
            ChoreTile(instance: instances[2], template: templates[3], streakCount: 3, parentName: "Dad",
                      onComplete: { _ in }, onPhotoRequired: { _ in })
            .tierTheme(.advanced)
        }
        .padding()
    }
}
