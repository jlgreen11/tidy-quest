import Foundation

// MARK: - StoreKit 2 Receipt

/// Mirrors `StoreKit2ReceiptSchema` in
/// `supabase/functions/subscription-update/schema.ts`.
///
/// The backend accepts a discriminated union keyed on `payloadType`. This struct
/// represents the `"storekit2-receipt"` branch — the decoded JWS payload sent
/// by the iOS client after on-device signature verification.
///
/// Field casing matches the Zod schema exactly (camelCase), so no custom
/// `CodingKeys` rewrite is required.
public struct StoreKit2Receipt: Codable, Sendable {
    /// Discriminator — always `"storekit2-receipt"`.
    public let payloadType: String
    public let transactionId: String
    public let originalTransactionId: String?
    public let productId: String
    /// ISO 8601 string with timezone offset, e.g. `2026-04-23T12:00:00+00:00`.
    public let purchaseDate: String?
    /// ISO 8601 string with timezone offset. Use `nil` to omit, or a
    /// sentinel-free absence is conveyed by omitting the field entirely (the
    /// server treats missing and null identically for this field).
    public let expiresDate: String?
    /// `"Sandbox"` or `"Production"`.
    public let environment: String?

    public init(
        payloadType: String = "storekit2-receipt",
        transactionId: String,
        originalTransactionId: String? = nil,
        productId: String,
        purchaseDate: String? = nil,
        expiresDate: String? = nil,
        environment: String? = nil
    ) {
        self.payloadType = payloadType
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
        self.productId = productId
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.environment = environment
    }
}
