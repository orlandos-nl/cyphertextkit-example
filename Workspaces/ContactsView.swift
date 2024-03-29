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
    
    var contacts: [Contact] {
        let matchingUsers: [Contact]
        if searchText.isEmpty {
            matchingUsers = viewModel.contacts
        } else {
            matchingUsers = viewModel.contacts.filter { $0.nickname.lowercased().contains(searchText.lowercased()) }
        }
    
        return matchingUsers.sorted { (lhs: Contact, rhs: Contact) in
            if lhs.isMutualFriendship != rhs.isMutualFriendship {
                // We care about undecided friend requests first
                // Then friendship before non-friendship
                switch (lhs.ourFriendshipState, rhs.ourFriendshipState) {
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
        Form {
            Section(header: Text("\(viewModel.contacts.count) contacts")) {
                if viewModel.contacts.isEmpty {
                    Text("No Contacts Yet")
                        .foregroundColor(.gray)
                }
                
                ForEach(contacts) { contact in
                    switch contact.ourFriendshipState {
                    case .undecided, .friend:
                        ContactRow(contact: contact)
                    case .notFriend, .blocked:
                        ContactRow(contact: contact).opacity(0.4)
                    }
                }
            }
            
            Section(header: Text("Actions")) {
                NavigationLink("Add Contact", destination: AddOnlineContact())
            }
        }.searchable(text: $searchText).navigationBarTitle("Contacts")
    }
}
