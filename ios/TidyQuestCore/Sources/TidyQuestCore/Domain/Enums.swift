// Domain/Enums.swift
// Mirrors every Postgres enum and CHECK-constraint enum in the schema.
// Values are the raw snake_case strings Postgres/JSON uses — zero transform on Codable.

// MARK: - User

public enum UserRole: String, Codable, Sendable, Hashable, CaseIterable {
    case parent
    case child
    case caregiver
    case observer
    case system
}

public enum ComplexityTier: String, Codable, Sendable, Hashable, CaseIterable {
    case starter
    case standard
    case advanced
}

// MARK: - Chore

public enum ChoreType: String, Codable, Sendable, Hashable, CaseIterable {
    case oneOff       = "one_off"
    case daily
    case weekly
    case monthly
    case seasonal
    case routineBound = "routine_bound"
}

public enum OnMissPolicy: String, Codable, Sendable, Hashable, CaseIterable {
    case skip
    case decay
    case deduct
}

public enum ChoreInstanceStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case completed
    case missed
    case approved
    case rejected
}

// MARK: - Points

public enum PointTxnKind: String, Codable, Sendable, Hashable, CaseIterable {
    case choreCompletion    = "chore_completion"
    case choreBonus         = "chore_bonus"
    case streakBonus        = "streak_bonus"
    case comboBonus         = "combo_bonus"
    case surpriseMultiplier = "surprise_multiplier"
    case questCompletion    = "quest_completion"
    case redemption
    case fine
    case adjustment
    case correction
    case systemGrant        = "system_grant"
}

// MARK: - Reward

public enum RewardCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case screenTime   = "screen_time"
    case treat
    case privilege
    case cashOut      = "cash_out"
    case savingGoal   = "saving_goal"
    case other
}

public enum RedemptionStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case fulfilled
    case denied
    case cancelled
}

// MARK: - Challenge

public enum ChallengeStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case draft
    case active
    case completed
    case expired
    case cancelled
}

// MARK: - Approval

public enum ApprovalRequestKind: String, Codable, Sendable, Hashable, CaseIterable {
    case choreInstance      = "chore_instance"
    case redemptionRequest  = "redemption_request"
    case transactionContest = "transaction_contest"
}

public enum ApprovalRequestStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case approved
    case denied
    case cancelled
}

// MARK: - Notification

public enum NotificationKind: String, Codable, Sendable, Hashable, CaseIterable {
    case choreApprovalNeeded      = "chore_approval_needed"
    case choreApproved            = "chore_approved"
    case choreRejected            = "chore_rejected"
    case redemptionApprovalNeeded = "redemption_approval_needed"
    case redemptionApproved       = "redemption_approved"
    case redemptionDenied         = "redemption_denied"
    case fineIssued               = "fine_issued"
    case streakMilestone          = "streak_milestone"
    case questStarted             = "quest_started"
    case questCompleted           = "quest_completed"
    case day2Reengage             = "day2_reengage"
    case subscriptionExpiring     = "subscription_expiring"
    case system
}

// MARK: - Audit

public enum AuditAction: String, Codable, Sendable, Hashable, CaseIterable {
    case familyCreate             = "family.create"
    case familyDelete             = "family.delete"
    case familyRecovery           = "family.recovery"
    case userAdd                  = "user.add"
    case userRemove               = "user.remove"
    case userRoleChange           = "user.role_change"
    case pointTransactionLarge    = "point_transaction.large"
    case pointTransactionReversal = "point_transaction.reversal"
    case redemptionApprove        = "redemption.approve"
    case redemptionDeny           = "redemption.deny"
    case rlsDeny                  = "rls.deny"
    case authFailed               = "auth.failed"
    case authDevicePair           = "auth.device_pair"
    case authDeviceRevoke         = "auth.device_revoke"
    case subscriptionStateChange  = "subscription.state_change"
    case photoUpload              = "photo.upload"
    case photoPurge               = "photo.purge"
}

// MARK: - Subscription

public enum SubscriptionTier: String, Codable, Sendable, Hashable, CaseIterable {
    case trial
    case monthly
    case yearly
    case expired
    case grace
}

public enum SubscriptionStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case trial
    case active
    case grace
    case expired
}
