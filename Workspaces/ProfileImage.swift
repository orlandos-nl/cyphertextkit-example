//
//  ProfileImage.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 14/06/2021.
//

import MessagingHelpers
import CypherMessaging
import SwiftUI

struct ContactImage: View {
    @Environment(\.plugin) var plugin
    let contact: Contact
    @State var data: Data?
    
    init(contact: Contact) {
        self.contact = contact
        self._data = .init(wrappedValue: contact.image)
    }
    
    var body: some View {
        ProfileImage(data: data).onReceive(plugin.contactChanged) { changedContact in
            if changedContact.id == self.contact.id, contact.image?.count != data?.count {
                data = contact.image
            }
        }
    }
}

struct ProfileImage: View {
    let data: Data?
    
    @ViewBuilder var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray))
        } else {
            Circle()
                .strokeBorder(Color.gray, lineWidth: 2)
                .overlay(
                    Image(systemName: "person")
                        .scaledToFit()
                        .foregroundColor(.gray)
                        .padding(8)
                )
        }
    }
}
