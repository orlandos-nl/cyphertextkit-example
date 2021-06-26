//
//  macOSApp.swift
//  macOS
//
//  Created by Joannis Orlandos on 21/06/2021.
//

import SwiftUI
import UserNotifications
import PushKit
import CallKit
import CypherMessaging
import MessagingHelpers

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    // Used for the purpose of a static fallback for the UI's `@Environment(\.appState)
    weak var cypherMessenger: CypherMessenger?
    static var voipRegistery: PKPushRegistry?
    static var pushCredentials: PKPushCredentials?
    static var token: Data?
    
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.token = deviceToken
        if let cypherMessenger = cypherMessenger, let transport = cypherMessenger.transport as? VaporTransport {
            detach {
                try await transport.registerAPNSToken(deviceToken)
            }
        }
    }
}

@main
struct macOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State var exists = SQLiteStore.exists()
    @StateObject var emitter = makeEventEmitter()
    
    var body: some Scene {
        WindowGroup {
            if exists {
                AsyncView(run: { () async throws -> CypherMessenger in
                    let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
                    let store = try await SQLiteStore.create(on: eventLoop)
                    let cypherMessenger = try await CypherMessenger.resumeMessenger(
                        appPassword: "",
                        usingTransport: { request in
                            try await VaporTransport.login(
                                for: request,
                                   host: Constants.host,
                                   eventLoop: eventLoop
                            )
                        },
                        p2pFactories: makeP2PFactories(),
                        database: store,
                        eventHandler: makeEventHandler(emitter: emitter),
                        on: eventLoop
                    )
                    await emitter.boot(for: cypherMessenger)
                    appDelegate.cypherMessenger = cypherMessenger
                    return cypherMessenger
                }) { messenger in
                    AppView()
                        .environment(\.messenger, messenger)
                        .environment(\.plugin, emitter)
                }
            } else {
                SetupView()
            }
        }.commands {
            CommandGroup(replacing: .newItem) {
                // Don't support new windows
            }
            SidebarCommands()
        }
    }
}
