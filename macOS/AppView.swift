//
//  ContentView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import UserNotifications
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
    @Environment(\.plugin) var plugin
    
    var body: some View {
        AsyncView(run: {
            await messenger.checkSetupCompleted()
        }) { isSetup in
            if isSetup {
                NavigationView {
                    ContactsView(viewModel: ContactsViewModel(emitter: plugin))
                        .frame(minWidth: 250, idealWidth: 300)
                    
                    EmptyView()
                        .frame(idealWidth: 450, idealHeight: 600)
                }
                .frame(minWidth: 800, idealWidth: 800, minHeight: 450, idealHeight: 600)
                .onAppear {
                    NSApplication.shared.registerForRemoteNotifications()
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
                }.onChange(of: scenePhase) { scenePhase in
                    switch scenePhase {
                    case .background:
                        Task.detached {
                            try await messenger.transport.disconnect()
                        }
                    case .active:
                        Task.detached {
                            try await messenger.transport.reconnect()
                        }
                    case .inactive:
                        ()
                    @unknown default:
                        ()
                    }
                }
            } else {
                AsyncView(run: { () async throws -> Image? in
                    if let request = try await messenger.createDeviceRegisteryRequest() {
                        let data = try BSONEncoder().encode(request).makeData()
                        return try generateQRCode(from: data)
                    } else {
                        return nil
                    }
                }) { qrCode in
                    qrCode.frame(width: 800, height: 800)
                }.frame(width: 800, height: 800)
            }
        }
    }
    
    @MainActor
    func generateQRCode(from data: Data) throws -> Image {
        struct BadQR: Error {}
        
        let base64 = data.base64EncodedData()
        
        let image = QRGenerator.create(
            data: base64,
            color: QRCode.Color(pointStart: .black, backgroundStart: .white),
            size: 512,
            correction: .highest
        )
        
        if let image = image {
            return Image(nsImage: image)
        } else {
            throw BadQR()
        }
    }
}
