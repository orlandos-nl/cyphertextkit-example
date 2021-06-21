//
//  PrivateChat.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import Combine
import SwiftUI
import SwiftUIX
import CypherMessaging
import Router
import MessagingHelpers

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
    @State var id = UUID()
    @Environment(\.messenger) var messenger
    @Environment(\.plugin) var plugin
    @Environment(\.presentationMode) var presentationMode
    @State var cursor: AnyChatMessageCursor
    @State var drained = false
    @State var canLoadMore = false
    @State var messages = [AnyChatMessage]()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack {
                        if !drained {
                            ProgressView().task {
                                if !canLoadMore {
                                    return
                                }
                                
                                let topMessage = messages.last
                                let messages = try? await cursor.getMore(50)
                                if let messages = messages {
                                    self.messages.append(contentsOf: messages)
                                    self.drained = messages.count < 50
                                }
                                
                                if let topMessage = topMessage {
                                    DispatchQueue.main.async {
                                        proxy.scrollTo(topMessage.id, anchor: .top)
                                    }
                                }
                            }
                        }
                        
                        ForEach(messages.lazy.reversed()) { message in
                            MessageCell(message: message).id(message.id)
                        }
                        
                        // Replaces padding bottom
                        Color.almostClear.frame(height: 12).id("bottom").onReceive(Keyboard.main.$isShown) { isShown in
                            withAnimation {
                                proxy.scrollTo("bottom")
                            }
                        }
                    }.padding(.top, 12).onReceive(plugin.savedChatMessages) { message in
                        if case .otherUser(chat.conversationPartner) = message.target {
                            messages.insert(message, at: 0)
                            proxy.scrollTo("bottom")
                        }
                    }.onChange(of: messages.isEmpty) { isEmpty in
                        if !isEmpty {
                            proxy.scrollTo("bottom")
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                                proxy.scrollTo("bottom")
                                canLoadMore = true
                            }
                        }
                    }
                }
            }
            .onTapGesture(perform: Keyboard.main.dismiss)
            .navigationBarTitle(contact.nickname, displayMode: .inline)
            
            Divider()
            
            Group {
                if contact.isBlocked {
                    Text("Contact is Blocked").foregroundColor(.gray)
                } else if contact.isMutualFriendship {
                    ChatBar(chat: chat, indicator: .init(chat: chat, emitter: plugin))
                } else if contact.ourState == .friend {
                    VStack {
                        Text("Contact Request Pending")
                        
                        Button("Resend Request", role: nil) {
                            try? await contact.befriend()
                            try? await contact.query()
                        }
                    }.padding()
                } else {
                    VStack {
                        Text("Contact Requested Contact")
                        
                        HStack {
                            Button("Accept", role: nil) {
                                try? await contact.befriend()
                                id = UUID()
                            }
                            
                            Button("Ignore", role: nil) {
                                try? await contact.unfriend()
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }.padding()
                }
            }.id(id)
        }.onReceive(plugin.contactChanged) { changedContact in
            if changedContact.id == contact.id {
                self.id = UUID()
            }
        }.task {
            do {
                let messages = try await cursor.getMore(50)
                self.messages.append(contentsOf: messages)
                self.drained = messages.count < 50
            } catch {
                self.drained = true
            }
        }
    }
}

final class TypingIndicator: ObservableObject {
    @Published var typingContacts = Set<Contact>()
    private var clients = [P2PClient]()
    var cancellables = Set<AnyCancellable>()
    private var isTyping = false
    
    func emitIsTyping(_ isTyping: Bool) async {
        if self.isTyping == isTyping {
            return
        }
        
        self.isTyping = isTyping
        var flags = P2PStatusMessage.StatusFlags()
        if isTyping {
            flags.insert(.isTyping)
        }
        
        for client in clients {
            _ = try? await client.updateStatus(flags: flags)
        }
    }
    
    private func addClient<Chat: AnyConversation>(_ client: P2PClient, for chat: Chat) {
        clients.append(client)
        detach {
            if
                let contact = try? await chat.messenger.createContact(byUsername: client.username),
                let status = client.remoteStatus
            {
                self.changeStatus(for: contact, to: status)
            }
        }
        
        client.onDisconnect { [weak self] in
            guard
                let indicator = self
            else {
                return
            }
            
            indicator.clients.removeAll { $0 === client }
            
            detach {
                if let contact = try? await chat.messenger.createContact(byUsername: client.username) {
                    indicator.typingContacts.remove(contact)
                }
            }
        }
        
        client.onStatusChange { [weak self] status in
            guard
                let indicator = self,
                let status = status
            else { return }
            
            detach {
                if let contact = try? await chat.messenger.createContact(byUsername: client.username) {
                    indicator.changeStatus(for: contact, to: status)
                }
            }
        }
    }
    
    private func changeStatus(for contact: Contact, to status: P2PStatusMessage) {
        DispatchQueue.main.async {
            if status.flags.contains(.isTyping) {
                self.typingContacts.insert(contact)
            } else {
                self.typingContacts.remove(contact)
            }
        }
    }
    
    init<Chat: AnyConversation>(chat: Chat, emitter: SwiftUIEventEmitter) {
        detach {
            let clients = try await chat.listOpenP2PConnections()
            for client in clients {
                self.addClient(client, for: chat)
            }
            emitter.p2pClientConnected.sink { [weak self] client in
                if chat.conversation.members.contains(client.username) {
                    self?.addClient(client, for: chat)
                }
            }.store(in: &self.cancellables)
            try await chat.buildP2PConnections()
        }
    }
}
