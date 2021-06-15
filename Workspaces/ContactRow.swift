//
//  privateChat.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import SwiftUI
import CypherMessaging
import Router

struct ContactRow: View {
    let contact: Contact
    @State var status: String
    @Environment(\.plugin) var plugin
    
    init(contact: Contact) {
        self.contact = contact
        self._status = .init(initialValue: contact.status ?? "Available")
    }
    
    var body: some View {
        RouterLink(to: Routes.contactPrivateChat(contact: contact)) {
            HStack(alignment: .top) {
                ContactImage(contact: contact)
                    .frame(width: 38, height: 38)
                
                VStack(alignment: .leading) {
                    Text(contact.username.raw)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(contact.status ?? "Available")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.gray)
                }.frame(height: 38)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.almostClear)
        }.onReceive(plugin.contactChanged) { changedContact in
            if changedContact.id == self.contact.id, contact.status != status {
                status = contact.status ?? "Available"
            }
        }
    }
}
