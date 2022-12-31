//
//  ChatsView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import SwiftUI
import CypherMessaging
import MessagingHelpers

public final class ChatsViewModel: ObservableObject {
    let emitter: SwiftUIEventEmitter
    
    init(emitter: SwiftUIEventEmitter) {
        self.emitter = emitter
    }
    
    public var contacts: [TargetConversation.Resolved] {
        emitter.conversations.sorted(by: sortConversations)
    }
    public var objectWillChange: Published<[TargetConversation.Resolved]>.Publisher {
        emitter.$conversations
    }
}

struct ChatsView: View {
    @Environment(\.plugin) var plugin
    @Environment(\.messenger) var messenger
    @StateObject var viewModel: ChatsViewModel
    
    var body: some View {
        List(plugin.conversations) { chat in
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
                        Button(role: .destructive, action: {
                            // TODO: Close chat
                        }) {
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
        .listStyle(.inset)
        .navigationBarTitle("Chats")
    }
}
