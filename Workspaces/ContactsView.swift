//
//  ContactsView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import BSON
import SwiftUI
import CypherMessaging
import Router
import MessagingHelpers

extension Routes {
    static var contacts: some Route {
        struct _ContactsViewWrapper: View {
            @Environment(\.messenger) var messenger
            @Environment(\.plugin) var plugin
            
            var body: some View {
                ContactsView(
                    viewModel: ContactsViewModel(emitter: plugin)
                )
            }
        }
        
        return SimpleRoute {
            _ContactsViewWrapper()
        }
    }
}

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
    @Environment(\.router) var router
    @Environment(\.routeViewId) var routeViewId
    @StateObject var viewModel: ContactsViewModel
    @State var searchText = ""
    
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
        Form {
            Section(header: "\(viewModel.contacts.count) contacts") {
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
            }
            
            Section(header: "Actions") {
                NavigationLink("Add Online Contact", destination: AddOnlineContact())
            }
        }.searchable(text: $searchText).navigationBarTitle("Contacts")
    }
}

extension PrivateChat: Identifiable {
    public var id: UUID { self.conversation.id }
}

extension GroupChat: Identifiable {
    public var id: UUID { self.conversation.id }
}
