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
    
    var body: some View {
        List {
            if viewModel.contacts.isEmpty {
                Text("No Contacts Yet")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                
                Button("Add Contact") {
                    router?.navigate(
                        to: Routes.addOnlineContact,
                        using: CustomActionSheetPresenter()
                    )
                }.font(.system(size: 15, weight: .medium))
            } else {
                ForEach(viewModel.contacts) { contact in
                    ContactRow(contact: contact)
                }
            }
        }
        .navigationTitle("Contacts")
        .navigationBarItems(
            trailing: Menu(content: {
                Button("Local Contact") {
                    router?.navigate(to: Routes.addLocalContact, using: SheetPresenter())
                }
                
                Button("Online Contact") {
                    router?.navigate(
                        to: Routes.addOnlineContact,
                        using: CustomActionSheetPresenter()
                    )
                }
            }) {
                Image(systemName: "plus")
            }
        )
    }
}

extension PrivateChat: Identifiable {
    public var id: UUID { self.conversation.id }
}

extension GroupChat: Identifiable {
    public var id: UUID { self.conversation.id }
}
