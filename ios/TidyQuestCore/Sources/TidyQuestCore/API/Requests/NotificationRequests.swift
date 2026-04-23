import Foundation

public struct RegisterAPNSTokenRequest: Codable, Sendable {
    public let token: String
    public let appBundle: String

    public init(token: String, appBundle: String) {
        self.token = token
        self.appBundle = appBundle
    }

    enum CodingKeys: String, CodingKey {
        case token
        case appBundle = "app_bundle"
    }
}
