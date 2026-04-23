/**
 * TidyQuest — Shared TypeScript enums and types
 * supabase/functions/_shared/types.ts
 *
 * These enums mirror the Postgres enums defined in migration 20260422000001.
 * All edge function agents import from this file; do NOT duplicate definitions.
 *
 * Naming convention: PascalCase enum name, SCREAMING_SNAKE_CASE values are
 * avoided in favour of snake_case strings matching Postgres exactly so that
 * JSON serialisation is zero-transform.
 */

// ---------------------------------------------------------------------------
// Chore
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: chore_type_kind */
export enum ChoreTypeKind {
  OneOff       = "one_off",
  Daily        = "daily",
  Weekly       = "weekly",
  Monthly      = "monthly",
  Seasonal     = "seasonal",
  RoutineBound = "routine_bound",
}

/** Mirrors Postgres enum: on_miss_policy */
export enum OnMissPolicy {
  Skip   = "skip",
  Decay  = "decay",
  Deduct = "deduct",
}

/** Mirrors Postgres enum: chore_instance_status */
export enum ChoreInstanceStatus {
  Pending   = "pending",
  Completed = "completed",
  Missed    = "missed",
  Approved  = "approved",
  Rejected  = "rejected",
}

// ---------------------------------------------------------------------------
// Point Transactions
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: point_txn_kind */
export enum PointTxnKind {
  ChoreCompletion    = "chore_completion",
  ChoreBonus         = "chore_bonus",
  StreakBonus        = "streak_bonus",
  ComboBonus         = "combo_bonus",
  SurpriseMultiplier = "surprise_multiplier",
  QuestCompletion    = "quest_completion",
  Redemption         = "redemption",
  Fine               = "fine",
  Adjustment         = "adjustment",
  Correction         = "correction",
  SystemGrant        = "system_grant",
}

// ---------------------------------------------------------------------------
// Redemption
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: redemption_status */
export enum RedemptionStatus {
  Pending   = "pending",
  Fulfilled = "fulfilled",
  Denied    = "denied",
  Cancelled = "cancelled",
}

// ---------------------------------------------------------------------------
// Challenge / Quest
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: challenge_status */
export enum ChallengeStatus {
  Draft     = "draft",
  Active    = "active",
  Completed = "completed",
  Expired   = "expired",
  Cancelled = "cancelled",
}

// ---------------------------------------------------------------------------
// Approval
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: approval_request_kind */
export enum ApprovalRequestKind {
  ChoreInstance      = "chore_instance",
  RedemptionRequest  = "redemption_request",
  TransactionContest = "transaction_contest",
}

/** Mirrors Postgres enum: approval_request_status */
export enum ApprovalRequestStatus {
  Pending   = "pending",
  Approved  = "approved",
  Denied    = "denied",
  Cancelled = "cancelled",
}

// ---------------------------------------------------------------------------
// Notification
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: notification_kind */
export enum NotificationKind {
  ChoreApprovalNeeded      = "chore_approval_needed",
  ChoreApproved            = "chore_approved",
  ChoreRejected            = "chore_rejected",
  RedemptionApprovalNeeded = "redemption_approval_needed",
  RedemptionApproved       = "redemption_approved",
  RedemptionDenied         = "redemption_denied",
  FineIssued               = "fine_issued",
  StreakMilestone          = "streak_milestone",
  QuestStarted             = "quest_started",
  QuestCompleted           = "quest_completed",
  Day2Reengage             = "day2_reengage",
  SubscriptionExpiring     = "subscription_expiring",
  System                   = "system",
}

// ---------------------------------------------------------------------------
// Audit
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: audit_action */
export enum AuditAction {
  FamilyCreate             = "family.create",
  FamilyDelete             = "family.delete",
  FamilyRecovery           = "family.recovery",
  UserAdd                  = "user.add",
  UserRemove               = "user.remove",
  UserRoleChange           = "user.role_change",
  PointTransactionLarge    = "point_transaction.large",
  PointTransactionReversal = "point_transaction.reversal",
  RedemptionApprove        = "redemption.approve",
  RedemptionDeny           = "redemption.deny",
  RlsDeny                  = "rls.deny",
  AuthFailed               = "auth.failed",
  AuthDevicePair           = "auth.device_pair",
  AuthDeviceRevoke         = "auth.device_revoke",
  SubscriptionStateChange  = "subscription.state_change",
  PhotoUpload              = "photo.upload",
  PhotoPurge               = "photo.purge",
}

// ---------------------------------------------------------------------------
// Subscription
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: subscription_status */
export enum SubscriptionStatus {
  Trial   = "trial",
  Active  = "active",
  Grace   = "grace",
  Expired = "expired",
}

/** Mirrors family.subscription_tier CHECK constraint values */
export enum SubscriptionTier {
  Trial   = "trial",
  Monthly = "monthly",
  Yearly  = "yearly",
  Expired = "expired",
  Grace   = "grace",
}

// ---------------------------------------------------------------------------
// Job log
// ---------------------------------------------------------------------------

/** Mirrors Postgres enum: job_status */
export enum JobStatus {
  Success = "success",
  Failure = "failure",
  Skipped = "skipped",
}

// ---------------------------------------------------------------------------
// User / family
// ---------------------------------------------------------------------------

/** Mirrors app_user.role CHECK constraint values */
export enum UserRole {
  Parent    = "parent",
  Child     = "child",
  Caregiver = "caregiver",
  Observer  = "observer",
  System    = "system",
}

/** Mirrors app_user.complexity_tier CHECK constraint values */
export enum ComplexityTier {
  Starter  = "starter",
  Standard = "standard",
  Advanced = "advanced",
}

// ---------------------------------------------------------------------------
// Structured error codes (edge function responses)
// ---------------------------------------------------------------------------

/** Standard error codes returned by all edge functions */
export enum EdgeErrorCode {
  // Chore errors
  ChoreAlreadyCompleted = "CHORE_ALREADY_COMPLETED",
  OutsideWindow         = "OUTSIDE_WINDOW",
  InvalidInstance       = "INVALID_INSTANCE",
  // Redemption errors
  InsufficientBalance   = "INSUFFICIENT_BALANCE",
  RewardUnavailable     = "REWARD_UNAVAILABLE",
  CooldownActive        = "COOLDOWN_ACTIVE",
  // Rate limiting
  RateLimitExceeded     = "RATE_LIMIT_EXCEEDED",
  // Deduction caps
  DailyDeductionCapExceeded  = "DAILY_DEDUCTION_CAP_EXCEEDED",
  WeeklyDeductionCapExceeded = "WEEKLY_DEDUCTION_CAP_EXCEEDED",
  // Auth / security
  Unauthorized          = "UNAUTHORIZED",
  Forbidden             = "FORBIDDEN",
  AppAttestRequired     = "APP_ATTEST_REQUIRED",
  AppAttestInvalid      = "APP_ATTEST_INVALID",
  // Generic
  InvalidInput          = "INVALID_INPUT",
  NotFound              = "NOT_FOUND",
  Conflict              = "CONFLICT",
  InternalError         = "INTERNAL_ERROR",
}

// ---------------------------------------------------------------------------
// Shared response envelope types
// ---------------------------------------------------------------------------

export interface EdgeErrorPayload {
  code: EdgeErrorCode;
  message: string;
  details?: Record<string, unknown>;
}

export interface EdgeErrorResponse {
  error: EdgeErrorPayload;
}

/** Type guard: narrows an unknown response to EdgeErrorResponse */
export function isEdgeError(res: unknown): res is EdgeErrorResponse {
  return (
    typeof res === "object" &&
    res !== null &&
    "error" in res &&
    typeof (res as EdgeErrorResponse).error?.code === "string"
  );
}

// ---------------------------------------------------------------------------
// System sentinel UUID constant
// ---------------------------------------------------------------------------

/** The system sentinel user ID. Used as created_by_user_id for automated transactions. */
export const SYSTEM_USER_ID = "00000000-0000-0000-0000-000000000000" as const;
