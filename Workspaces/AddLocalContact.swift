//
//  AddLocalUser.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//


import SwiftUI
import MultipeerConnectivity
import CypherMessaging
import Router

extension Routes {
    static let addLocalContact = SimpleRoute {
        AddLocalContact()
    }
}

struct AddLocalContact: View {
    @State var invitation: Invitation?
    @Environment(\.router) var router
    @Environment(\.routeViewId) var routeViewId
    @Environment(\.messenger) var messenger
    
    var body: some View {
        // TODO: Custom nearby contacts browser
        MCBrowser { invitation in
            self.invitation = invitation
        }.sheet(item: $invitation) { invitation in
            NavigationView {
                VStack {
                    Text("""
                    You've been invited to chat with \(invitation.peerID.displayName).
                    """).padding(8)
                    
                    Spacer()
                }
                .navigationTitle("Chat Invite")
                .navigationBarItems(trailing: Button("Accept", role: nil) {
                    do {
                        _ = try await messenger.createPrivateChat(with: Username(invitation.peerID.displayName))
                        self.invitation = nil
                        self.router?.dismissUpToIncluding(routeMatchingId: routeViewId)
                    } catch {}
                })
            }
        }
    }
}

struct Invitation: Identifiable {
    let id: UUID
    let peerID: MCPeerID
    let handler: (Bool, MCSession?) -> Void
}

struct MCBrowser: UIViewControllerRepresentable {
    let handleInvitation: (Invitation) -> ()
    @Environment(\.messenger) var messenger
    
    final class Coordinator: NSObject, MCBrowserViewControllerDelegate, MCNearbyServiceAdvertiserDelegate {
        let peerId: MCPeerID
        let session: MCSession
        let assistant: MCNearbyServiceAdvertiser
        let handleInvitation: (Invitation) -> ()
        
        init(displayName: String, handleInvitation: @escaping (Invitation) -> ()) {
            self.peerId = MCPeerID(displayName: displayName)
            self.session = MCSession(
                peer: self.peerId,
                securityIdentity: nil,
                encryptionPreference: .required
            )
            self.assistant = MCNearbyServiceAdvertiser(
                peer: self.peerId,
                discoveryInfo: nil,
                serviceType: "orla-workspaces"
            )
            self.handleInvitation = handleInvitation
            
            super.init()
            
            assistant.delegate = self
            assistant.startAdvertisingPeer()
        }
        
        func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
            
        }
        
        func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
            
        }
        
        func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
            let invitation = Invitation(
                id: UUID(),
                peerID: peerID,
                handler: invitationHandler
            )
            self.handleInvitation(invitation)
        }
        
        deinit {
            assistant.stopAdvertisingPeer()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            displayName: messenger.username.raw,
            handleInvitation: handleInvitation
        )
    }
    
    func makeUIViewController(context: Context) -> MCBrowserViewController {
        let uiViewController = MCBrowserViewController(
            browser: MCNearbyServiceBrowser(
                peer: context.coordinator.peerId,
                serviceType: "orla-workspaces"
            ),
            session: context.coordinator.session
        )
        uiViewController.minimumNumberOfPeers = 1
        uiViewController.maximumNumberOfPeers = 1
        uiViewController.delegate = context.coordinator
        return uiViewController
    }
    
    func updateUIViewController(_ uiViewController: MCBrowserViewController, context: Context) {}
}
