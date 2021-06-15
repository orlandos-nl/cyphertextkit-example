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

func makeEventEmitter() -> SwiftUIEventEmitter {
    SwiftUIEventEmitter { lhs, rhs in
        switch (lhs.isPinned, rhs.isPinned) {
        case (true, true), (false, false):
            ()
        case (true, false):
            return true
        case (false, true):
            return false
        }
        
        switch (lhs.lastActivity, rhs.lastActivity) {
        case (.some(let lhs), .some(let rhs)):
            return lhs > rhs
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return true
        }
    }
}

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
    @StateObject var emitter = makeEventEmitter()
    
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
