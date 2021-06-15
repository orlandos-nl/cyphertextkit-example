//
//  ChatsView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import SwiftUI
import Router

extension Routes {
    static var chats: some Route {
        struct _ChatsViewWrapper: View {
            @Environment(\.messenger) var messenger
            
            var body: some View {
                ChatsView()
            }
        }
        
        return SimpleRoute {
            _ChatsViewWrapper()
        }
    }
}

struct ChatsView: View {
    @Environment(\.router) var router
    @Environment(\.plugin) var plugin
    @Environment(\.messenger) var messenger
    @Environment(\.routeViewId) var routeViewId
    
    var body: some View {
        List {
            ForEach(plugin.conversations) { chat in
                switch chat {
                case .privateChat(let chat):
                    if let contact = plugin.contacts.first(where: { $0.username == chat.conversationPartner }) {
                        ChatRow(
                            contact: contact,
                            privateChat: chat,
                            mostRecentMessage: MostRecentMessage(
                                chat: chat,
                                plugin: plugin
                            )
                        ).swipeActions(edge: .trailing) {
                            Button(role: .destructive, action: {}) {
                                ZStack {
                                    Color.red
                                    Image(systemName: "xmark.octagon.fill")
                                        .scaledToFit()
                                        .foregroundColor(.white)
                                        .padding(8)
                                }
                            }
                        }
                    }
                case .groupChat, .internalChat:
                    EmptyView()
                }
            }
        }.listStyle(InsetListStyle())
    }
}
