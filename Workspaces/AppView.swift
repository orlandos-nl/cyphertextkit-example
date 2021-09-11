//
//  ContentView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import CypherMessaging
import MessagingHelpers

extension EnvironmentValues {
    private struct SwiftUIEventEmitterKey: EnvironmentKey {
        typealias Value = SwiftUIEventEmitter
        
        static let defaultValue = makeEventEmitter()
    }
    
    private struct CypherMessengerKey: EnvironmentKey {
        typealias Value = CypherMessenger?
        
        static let defaultValue: CypherMessenger? = nil
    }
    
    var _messenger: CypherMessenger? {
        get {
            self[CypherMessengerKey.self]
        }
        set {
            self[CypherMessengerKey.self] = newValue
        }
    }
    
    var messenger: CypherMessenger {
        get {
            self[CypherMessengerKey.self]!
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

struct AppView: View {
    @State var selection = BottomBarItem.chats
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.messenger) var messenger
    
    var body: some View {
        NavigationView {
            ChatTabView(selection: $selection)
        }
    }
}
