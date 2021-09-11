//
//  ChatRow.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 19/04/2021.
//

import SwiftUI
import Combine
import CypherMessaging
import MessagingHelpers
import SwiftUIX

final class MostRecentMessage<Chat: AnyConversation>: ObservableObject {
    @Published var message: AnyChatMessage?
    let chat: Chat
    private var cancellable: AnyCancellable?
    
    init(chat: Chat, plugin: SwiftUIEventEmitter) {
        self.chat = chat
        
        Task.detached {
            let cursor = try await chat.cursor(sortedBy: .descending)
            let message = try await cursor.getNext()
            DispatchQueue.main.async {
                self.message = message
            }
        }
        
        cancellable = plugin.savedChatMessages.sink { [weak self] message in
            if message.raw.encrypted.conversationId == chat.conversation.id {
                self?.message = message
            }
        }
    }
}

struct ChatRow: View {
    let contact: Contact
    let privateChat: PrivateChat
    @State var isPinned: Bool
    @State var isUnread: Bool
    @State var id = UUID()
    @Environment(\.plugin) var plugin
    @StateObject var mostRecentMessage: MostRecentMessage<PrivateChat>
    
    init(
        contact: Contact,
        privateChat: PrivateChat,
        mostRecentMessage: MostRecentMessage<PrivateChat>
    ) {
        self.contact = contact
        self.privateChat = privateChat
        self._isPinned = .init(wrappedValue: privateChat.isPinned)
        self._isUnread = .init(wrappedValue: privateChat.isMarkedUnread)
        self._mostRecentMessage = .init(wrappedValue: mostRecentMessage)
    }
    
    var body: some View {
        NavigationLink(
            destination: AsyncView(run: { () async throws -> AnyChatMessageCursor in
                try await privateChat.cursor(sortedBy: .descending)
            }) { cursor in
                PrivateChatView(
                    chat: privateChat,
                    contact: contact,
                    cursor: cursor
                )
            }
        ) {
            HStack(alignment: .top) {
                ContactImage(contact: contact)
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) {
                        if
                            let message = mostRecentMessage.message,
                            message.sender == contact.username,
                            message.raw.deliveryState != .read
                        {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                                .transition(.scale(scale: 0.1, anchor: .center).animation(.easeInOut))
                        } else if isUnread {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                                .transition(.scale(scale: 0.1, anchor: .center).animation(.easeInOut))
                        }
                    }
                
                VStack {
                    HStack {
                        Text(contact.username.raw)
                            .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                        
                        if let sentDate = mostRecentMessage.message?.sentDate {
                            Text(date: sentDate)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        } else if let lastActivity = privateChat.lastActivity {
                            Text(date: lastActivity)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        if let message = mostRecentMessage.message {
                            switch message.messageType {
                            case .text:
                                Text(message.text)
                                    .lineLimit(1)
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(.gray)
                            case .media:
                                // TODO: More detail
                                Text("Media")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(.gray)
                            case .magic:
                                Text("")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text("...")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if isPinned {   
                            Text(Image(systemName: "pin"))
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(.gray)
                        }
                    }
                }.frame(height: 44).background(Color.almostClear)
            }
        }.padding(.vertical, 4).contextMenu {
            if !isUnread {
                Button {
                    self.isUnread = true
                    self.id = UUID()
                    
                    Task.detached {
                        _ = try await self.privateChat.markUnread()
                    }
                } label: {
                    Label("Mark as Unread", systemImage: "bell")
                }
            }
            
            if isUnread {
                Button {
                    isUnread = false
                    self.id = UUID()
                    
                    Task.detached {
                        _ = try await self.privateChat.unmarkUnread()
                        _ = try await mostRecentMessage.message?.markAsRead()
                    }
                } label: {
                    Label("Mark as Read", systemImage: "bell")
                }
            } else if
                let message = mostRecentMessage.message,
                message.sender == contact.username,
                message.raw.deliveryState != .read
            {
                Button {
                    self.isUnread = true
                    self.id = UUID()
                    
                    Task.detached {
                        _ = try await mostRecentMessage.message?.markAsRead()
                    }
                } label: {
                    Label("Mark as Read", systemImage: "bell")
                }
            }
            
            if privateChat.isPinned {
                Button {
                    self.isPinned = false
                    self.id = UUID()
                    
                    Task.detached {
                        _ = try await privateChat.unpin()
                    }
                } label: {
                    Label("Unpin from Top", systemImage: "pin.slash")
                }
            } else {
                Button {
                    self.isPinned = true
                    self.id = UUID()
                    Task.detached {
                        _ = try await privateChat.pin()
                    }
                } label: {
                    Label("Pin to Top", systemImage: "pin")
                }
            }
        }.id(id)
    }
}
