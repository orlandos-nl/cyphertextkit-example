//
//  AddOnlineContact.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import CypherProtocol

struct AddOnlineContact: View {
    @State var nickname = ""
    @State var username = ""
    @State var attempted = false
    @Environment(\.messenger) var messenger
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                    .keyboardType(.asciiCapable)
                    .disableAutocorrection(true)
                    .overlay(Group {
                        if username.isEmpty && attempted {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .padding(.trailing, 8)
                        }
                    }, alignment: .trailing)
                
                TextField("Nickname", text: $nickname)
                    .keyboardType(.namePhonePad)
                    .disableAutocorrection(true)
                    .overlay(Group {
                        if nickname.isEmpty && attempted {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .padding(.trailing, 8)
                        }
                    }, alignment: .trailing)
            }
            
            Section {
                Button("Add Contact", role: nil) {
                    if username.isEmpty || nickname.isEmpty {
                        attempted = true
                        return
                    }
                    do {
                        let chat = try await messenger.createPrivateChat(with: Username(username))
                        let contact = try await messenger.createContact(byUsername: Username(username))
                        try await contact.befriend()
                        try await contact.setNickname(to: nickname)
                        _ = try await chat.sendRawMessage(
                            type: .magic,
                            messageSubtype: "_/ignore",
                            text: "",
                            preferredPushType: .contactRequest
                        )
                        presentationMode.wrappedValue.dismiss()
                    } catch {}
                }
            }
        }.navigationBarTitle("Add Contacty")
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
        .background(RoundedRectangle(cornerRadius: 8).fill(fill))
    }
}

struct AddOnlineContact_Previews: PreviewProvider {
    static var previews: some View {
        return AddOnlineContact()
            .environment(\.messenger, .test)
    }
}
