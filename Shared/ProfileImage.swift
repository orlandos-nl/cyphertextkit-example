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

extension Image {
    init?(data: Data) {
        #if os(iOS)
        guard let image = UIImage(data: data) else {
            return nil
        }
        
        self.init(uiImage: image)
        #else
        guard let image = NSImage(data: data) else {
            return nil
        }
        
        self.init(nsImage: image)
        #endif
    }
}

struct ProfileImage: View {
    let data: Data?
    
    @ViewBuilder var body: some View {
        if let data = data, let image = Image(data: data) {
            image
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
