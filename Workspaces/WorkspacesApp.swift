//
//  WorkspacesApp.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import NIO
import CypherMessaging
import MessagingHelpers

func makeEventHandler(emitter: SwiftUIEventEmitter) -> PluginEventHandler {
    PluginEventHandler(plugins: [
        FriendshipPlugin(ruleset: {
            var ruleset = FriendshipRuleset()
            ruleset.ignoreWhenUndecided = true
            ruleset.preventSendingDisallowedMessages = true
            return ruleset
        }()),
        UserProfilePlugin(),
        ChatActivityPlugin(),
        SwiftUIEventEmitterPlugin(emitter: emitter),
    ])
}

enum Constants {
    static let host = "chat-api.orlandos.nl"
}

@main
struct WorkspacesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State var exists = SQLiteStore.exists()
    @StateObject var emitter = SwiftUIEventEmitter()
    
    var body: some Scene {
        WindowGroup {
            if exists {
                AsyncView(run: {
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
        }
    }
}
