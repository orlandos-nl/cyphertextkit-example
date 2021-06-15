//
//  ChatRow.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 19/04/2021.
//

import SwiftUI
import Combine
import CypherMessaging
import Router
import MessagingHelpers
import SwiftUIX

final class MostRecentMessage<Chat: AnyConversation>: ObservableObject {
    @Published var message: AnyChatMessage?
    let chat: Chat
    private var cancellable: AnyCancellable?
    
    init(chat: Chat, plugin: SwiftUIEventEmitter) {
        self.chat = chat
        
        asyncDetached {
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
    @StateObject var mostRecentMessage: MostRecentMessage<PrivateChat>
    
    var body: some View {
        RouterLink(to: Routes.privateChat(privateChat, contact: contact)) {
            HStack {
                ProfileImage(data: contact.image)
                    .frame(width: 38, height: 38)
                    .overlay(Group {
                        if
                            let message = mostRecentMessage.message,
                            message.sender == contact.username,
                            message.raw.deliveryState != .read
                        {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                        }
                    }, alignment: .topTrailing)
                
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
                            Text("<Chat Started>")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                }.frame(height: 38).background(Color.almostClear)
            }
        }
    }
}
