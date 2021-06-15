//
//  PrivateChat.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import SwiftUI
import CypherMessaging
import Router

extension Routes {
    static func contactPrivateChat(contact: Contact) -> some Route {
        struct _ContactPrivateChatWrapper: View {
            @Environment(\.messenger) var messenger
            let contact: Contact
            
            var body: some View {
                AsyncView(run: { () async throws -> (PrivateChat, AnyChatMessageCursor) in
                    let chat = try await messenger.createPrivateChat(with: contact.username)
                    let cursor = try await chat.cursor(sortedBy: .descending)
                    return (chat, cursor)
                }) { chat, cursor in
                    PrivateChatView(
                        chat: chat,
                        contact: contact,
                        cursor: cursor
                    )
                }
            }
        }
        
        return SimpleRoute {
            _ContactPrivateChatWrapper(contact: contact)
        }
    }
    
    static func privateChat(_ chat: PrivateChat, contact: Contact) -> some Route {
        SimpleRoute {
            AsyncView(run: {
                try await chat.cursor(sortedBy: .descending)
            }) { cursor in
                PrivateChatView(chat: chat, contact: contact, cursor: cursor)
            }
        }
    }
}

extension AnyChatMessage: Hashable, Identifiable {
    public var id: UUID {
        raw.id
    }
    
    public static func == (lhs: AnyChatMessage, rhs: AnyChatMessage) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

struct PrivateChatView: View {
    let chat: PrivateChat
    let contact: Contact
    @Environment(\.messenger) var messenger
    @Environment(\.plugin) var plugin
    @State var cursor: AnyChatMessageCursor
    @State var messages = [AnyChatMessage]()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        LazyVStack {
                            ForEach(messages.lazy.reversed()) { message in
                                MessageCell(message: message)
                            }
                        }.padding(.vertical, 12)
                        
                        Color.almostClear.frame(height: 1).id("bottom")
                    }.onReceive(plugin.savedChatMessages) { message in
                        if case .otherUser(chat.conversationPartner) = message.target {
                            messages.insert(message, at: 0)
                            proxy.scrollTo("bottom")
                        }
                    }.onChange(of: messages.isEmpty) { isEmpty in
                        if !isEmpty {
                            proxy.scrollTo("bottom")
                        }
                    }
                }
            }.navigationTitle(contact.username.raw)
            
            Divider()
            
            if contact.isBlocked {
                Text("Contact is Blocked").foregroundColor(.gray)
            } else if contact.isMutualFriendship {
                ChatBar(chat: chat)
            } else if contact.ourState == .friend {
                VStack {
                    Text("Contact Request Pending...")
                    
                    Button("Resend Request", role: nil) {
                        try? await contact.befriend()
                        try? await contact.query()
                    }
                }.padding()
            } else {
                VStack {
                    Text("Contact Requested Contact")
                    
                    Button("Accept", role: nil) {
                        try? await contact.befriend()
                    }
                }.padding()
            }
        }.onAppear {
            asyncDetached {
                messages += try await cursor.getMore(50)
            }
        }
    }
}

struct ChatBar<Chat: AnyConversation>: View {
    let chat: Chat
    @State var message = ""
    
    var body: some View {
        HStack {
            ExpandingTextView(
                "Message",
                text: $message,
                heightRange: 16..<80,
                isDisabled: .constant(false)
            )
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.9)))
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.95)))
            
            Button("Send", role: nil) {
                if message.isEmpty { return }
                
                do {
                    try await chat.sendRawMessage(type: .text, text: message, preferredPushType: .message)
                    message = ""
                } catch {}
            }.disabled(message.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}
