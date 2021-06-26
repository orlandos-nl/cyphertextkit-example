//
//  TabViewPresenter.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import SwiftUI
import CoreImage
import BSON

struct ChatTabView: View {
    @Binding var selection: BottomBarItem
    @Environment(\.messenger) var messenger
    @Environment(\.plugin) var plugin
    @State var unacceptedContacts = 0
    @State var unreadChats = 0
    
    @ViewBuilder var body: some View {
        TabView(selection: $selection) {
            ContactsView(
                viewModel: ContactsViewModel(emitter: plugin)
            ).tabItem {
                Image(systemName: "person.3")
                
                Text(BottomBarItem.contacts.title)
            }.tag(BottomBarItem.contacts).badge(unacceptedContacts)
            
            #if os(iOS)
            ChatsView(
                viewModel: ChatsViewModel(emitter: plugin)
            ).tabItem {
                Image(systemName: "text.bubble")

                Text(BottomBarItem.chats.title)
            }.tag(BottomBarItem.chats).badge(unreadChats)

            AsyncView(run: {
                try await messenger.readProfileMetadata()
            }) { metadata in
                SettingsView(metadata: metadata)
            }.tabItem {
                Image(systemName: "gear")

                Text(BottomBarItem.settings.title)
            }.tag(BottomBarItem.settings)
            #endif
        }.edgesIgnoringSafeArea(.all).task {
            try? await recalculateBadges()
        }.onReceive(plugin.conversationChanged) { _ in
            detach {
                try await recalculateBadges()
            }
        }.onReceive(plugin.conversationAdded) { _ in
            detach {
                try await recalculateBadges()
            }
        }.onReceive(plugin.contactAdded) { _ in
            detach {
                try await recalculateBadges()
            }
        }
    }
    
    @MainActor func recalculateBadges() async throws {
        var unacceptedContactsCount = 0
        var unreadChatsCount = 0
        
        for contact in try await messenger.listContacts() {
            if contact.ourState == .undecided {
                unacceptedContactsCount += 1
            }
        }
        
        for chat in try await messenger.listConversations(
            includingInternalConversation: false,
            increasingOrder: { _, _ in return true }
        ) {
            if chat.isMarkedUnread {
                unreadChatsCount += 1
            } else if
                let message = try await chat.cursor(sortedBy: .descending).getNext(),
                message.raw.deliveryState != .read,
                message.sender != messenger.username
            {
                unreadChatsCount += 1
            }
        }
        
        unacceptedContacts = unacceptedContactsCount
        unreadChats = unreadChatsCount
    }
}

enum BottomBarItem: Int, Identifiable {
    case contacts, chats, settings
    
    var title: String {
        switch self {
        case .contacts:
            return "Contacts"
        case .chats:
            return "Chats"
        case .settings:
            return "Settings"
        }
    }
    
    var id: Int { rawValue }
}
