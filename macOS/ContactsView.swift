//
//  ContactsView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import BSON
import SwiftUI
import CypherMessaging
import MessagingHelpers

public final class ContactsViewModel: ObservableObject {
    let emitter: SwiftUIEventEmitter
    
    init(emitter: SwiftUIEventEmitter) {
        self.emitter = emitter
    }
    
    public var contacts: [Contact] {
        emitter.contacts
    }
    public var objectWillChange: Published<[Contact]>.Publisher {
        emitter.$contacts
    }
}

struct ContactsView: View {
    @StateObject var viewModel: ContactsViewModel
    @State var searchText = ""
    @State var addingContact = false
    
    var contacts: [Contact] {
        let matchingUsers: [Contact]
        if searchText.isEmpty {
            matchingUsers = viewModel.contacts
        } else {
            matchingUsers = viewModel.contacts.filter { $0.nickname.lowercased().contains(searchText.lowercased()) }
        }
    
        return matchingUsers.sorted { lhs, rhs in
            if lhs.isMutualFriendship != rhs.isMutualFriendship {
                // We care about undecided friend requests first
                // Then friendship before non-friendship
                switch (lhs.ourState, rhs.ourState) {
                case (.undecided, _):
                    return true
                case (_, .undecided):
                    return false
                case (.friend, _):
                    return true
                case (_, .friend):
                    return false
                case (_, _):
                    // Don't filter based on our state
                    ()
                }
            }
            
            // Ascending by nickname
            return lhs.nickname.lowercased() < rhs.nickname.lowercased()
        }
    }
    
    var body: some View {
        List {
            if viewModel.contacts.isEmpty {
                Text("No Contacts Yet")
                    .foregroundColor(.gray)
            }
            
            ForEach(contacts) { contact in
                switch contact.ourState {
                case .undecided, .friend:
                    ContactRow(contact: contact)
                case .notFriend, .blocked:
                    ContactRow(contact: contact).opacity(0.4)
                }
            }
        }.searchable(text: $searchText, placement: .sidebar, prompt: Text("Find Contact")).sheet(isPresented: $addingContact) {
            AddOnlineContact()
                .navigationTitle("Add Contact")
        }.toolbar {
            Spacer()
            Button(action: {
                addingContact = true
            }) {
                Image(systemName: "person.badge.plus")
            }
        }.accentColor(.white)
    }
}

struct AddOnlineContact: View {
    @State var nickname = ""
    @State var username = ""
    @State var attempted = false
    @State var userError = false
    @Environment(\.messenger) var messenger
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Add Contact")
                    .font(.title2)
                    .bold()
                    .padding()
                
                Spacer()
                
                Image(systemName: "xmark").onTapGesture {
                    presentationMode.wrappedValue.dismiss()
                }.padding()
            }
            
            Divider()
            
            Form {
                Section {
                    TextField("Username", text: $username)
                        .disableAutocorrection(true)
                        .overlay(Group {
                            if username.isEmpty && attempted {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .padding(.trailing, 8)
                            }
                        }, alignment: .trailing)
                    
                    TextField("Nickname", text: $nickname)
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
                    HStack {
                        if userError {
                            Text("Failed to add user").foregroundColor(.red)
                        }
                        
                        Spacer(minLength: 8)
                        
                        Button("Add Contact") {
                            if username.isEmpty || nickname.isEmpty {
                                attempted = true
                                return
                            }
                            
                            self.userError = false
                            
                            Task.detached {
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
                                } catch {
                                    self.userError = true
                                    return
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }.padding().background(Color(white: 0.97))
        }.frame(width: 350)
    }
}
