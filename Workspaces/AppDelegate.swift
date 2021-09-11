import SwiftUI
import UserNotifications
import PushKit
import CallKit
import CypherMessaging
import MessagingHelpers

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Used for the purpose of a static fallback for the UI's `@Environment(\.appState)
    weak var cypherMessenger: CypherMessenger?
    static var voipRegistery: PKPushRegistry?
    static var pushCredentials: PKPushCredentials?
    static var token: Data?
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.token = deviceToken
        if let cypherMessenger = cypherMessenger, let transport = cypherMessenger.transport as? VaporTransport {
            Task.detached {
                try await transport.registerAPNSToken(deviceToken)
            }
        }
    }
}
