//
//  AddOnlineContact.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import CypherProtocol
import Router

extension Routes {
    static let addOnlineContact = SimpleRoute {
        AddOnlineContact()
    }
}

struct AddOnlineContact: View {
    @State var nickname = ""
    @State var username = ""
    @State var attempted = false
    @Environment(\.messenger) var messenger
    @Environment(\.router) var router
    @Environment(\.routeViewId) var routeViewId
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.asciiCapable)
                    .overlay(Group {
                        if username.isEmpty && attempted {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .padding(.trailing, 8)
                        }
                    }, alignment: .trailing)
                
                TextField("Nickname", text: $nickname)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.namePhonePad)
                    .overlay(Group {
                        if nickname.isEmpty && attempted {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .padding(.trailing, 8)
                        }
                    }, alignment: .trailing)
            }.padding(12)
            
            Divider()
            
            Button("Add Contact", role: nil) {
                if username.isEmpty || nickname.isEmpty {
                    attempted = true
                } else {
                    do {
                        _ = try await messenger.createPrivateChat(with: Username(username))
                        let contact = try await messenger.createContact(byUsername: Username(username))
                        try await contact.befriend()
                        try await contact.setNickname(to: nickname)
                        router?.dismissUpToIncluding(routeMatchingId: routeViewId)
                    } catch {}
                }
            }
            .buttonStyle(RoundedBorderButtonStyle(fill: (nickname.isEmpty || username.isEmpty) ? Color.blue.opacity(0.7) : .blue))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(12)
        }
    }
}

struct RoundedBorderButtonStyle: ButtonStyle {
    let fill: Color
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Spacer()
            configuration.label
            Spacer()
        }
        .frame(minHeight: 40)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white)
        .background(RoundedRectangle(cornerRadius: 8).fill(fill))
    }
}

struct AddOnlineContact_Previews: PreviewProvider {
    static var previews: some View {
        return AddOnlineContact()
            .environment(\.messenger, .test)
    }
}
