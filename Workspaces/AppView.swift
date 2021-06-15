//
//  ContentView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import CypherMessaging
import MessagingHelpers
import Router

extension EnvironmentValues {
    private struct SwiftUIEventEmitterKey: EnvironmentKey {
        typealias Value = SwiftUIEventEmitter
        
        static let defaultValue = makeEventEmitter()
    }
    
    private struct CypherMessengerKey: EnvironmentKey {
        typealias Value = CypherMessenger
        
        static let defaultValue = CypherMessenger.test
    }
    
    var messenger: CypherMessenger {
        get {
            self[CypherMessengerKey.self]
        }
        set {
            self[CypherMessengerKey.self] = newValue
        }
    }
    
    var plugin: SwiftUIEventEmitter {
        get {
            self[SwiftUIEventEmitterKey.self]
        }
        set {
            self[SwiftUIEventEmitterKey.self] = newValue
        }
    }
}


enum Routes {}

struct AppView: View {
    @State var router = WorkspacesRouter(navigationController: WorkspaceNavigationController())
    @State var selection = BottomBarItem.chats
    
    var body: some View {
        UINavigationControllerRouterView(router: router)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                router.replaceRoot(with: Routes.tabView(selection: $selection))
                UIApplication.shared.registerForRemoteNotifications()
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    if settings.badgeSetting == .enabled {
                        return
                    } else if settings.soundSetting == .enabled {
                        return
                    } else if settings.alertSetting == .enabled {
                        return
                    }
                    
                    UNUserNotificationCenter.current().requestAuthorization(options: [
                        .badge, .sound, .alert
                    ]) { _, _ in }
                }
            }
    }
}

final class WorkspaceNavigationController: UINavigationController {}

final class WorkspacesRouter: UINavigationControllerRouter {
    override func makeChildRouter<RootRoute: EnvironmentDependentRoute>(
        rootRoute: RootRoute,
        environmentObject: RootRoute.EnvironmentObjectDependency,
        presentationContext: PresentationContext,
        presenterViewModel: PresenterViewModel
    ) -> UINavigationControllerRouter {
        WorkspacesRouter(
            navigationController: WorkspaceNavigationController(),
            root: rootRoute,
            environmentObject,
            parent: (self, presentationContext)
        )
    }
}

extension CypherMessenger {
    static var test: CypherMessenger {
        let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
        
        return try! eventLoop.executeAsync {
            try await CypherMessenger.registerMessenger(
                username: "test",
                appPassword: "test",
                usingTransport: { request in
                    try await SpoofTransportClient.login(
                        Credentials(
                            username: request.username,
                            deviceId: request.deviceId,
                            method: .password("")
                        ),
                        eventLoop: eventLoop
                    )
                },
                database: MemoryCypherMessengerStore(eventLoop: eventLoop),
                eventHandler: SpoofCypherEventHandler(),
                on: eventLoop
            )
        }.wait()
    }
}
