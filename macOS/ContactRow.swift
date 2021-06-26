//
//  privateChat.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import SwiftUI
import CypherMessaging

struct ContactRow: View {
    let contact: Contact
    @State var status: String
    @Environment(\.messenger) var messenger
    @Environment(\.plugin) var plugin
    
    init(contact: Contact) {
        self.contact = contact
        self._status = .init(initialValue: contact.status ?? "Available")
    }
    
    var body: some View {
        NavigationLink {
            AsyncView(run: { () async throws -> (PrivateChat, AnyChatMessageCursor) in
                let chat = try await messenger.createPrivateChat(with: contact.username)
                let cursor = try await chat.cursor(sortedBy: .descending)
                return (chat, cursor)
            }) { chat, cursor in
                PrivateChatView(
                    chat: chat,
                    contact: contact,
                    cursor: cursor
                )
            }
        } label: {
            HStack(alignment: .top) {
                ContactImage(contact: contact)
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) {
                        if contact.ourState == .undecided {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                                .transition(.scale(scale: 0.1, anchor: .center).animation(.easeInOut))
                        }
                    }
                
                VStack(alignment: .leading) {
                    Text(contact.username.raw)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(contact.status ?? "Available")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.gray)
                }.frame(height: 44)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color.almostClear)
        }.onReceive(plugin.contactChanged) { changedContact in
            if changedContact.id == self.contact.id, contact.status != status {
                status = contact.status ?? "Available"
            }
        }
    }
}
