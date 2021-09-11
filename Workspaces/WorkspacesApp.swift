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

@main
struct WorkspacesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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
                                   host: Constants.host
                            )
                        },
                        p2pFactories: makeP2PFactories(),
                        database: store,
                        eventHandler: makeEventHandler(emitter: emitter)
                    )
                    await emitter.boot(for: cypherMessenger)
                    appDelegate.cypherMessenger = cypherMessenger
                    return cypherMessenger
                }) { messenger in
                    AppView()
                        .environment(\._messenger, messenger)
                        .environment(\.plugin, emitter)
                }
            } else {
                SetupView()
            }
        }
    }
}
