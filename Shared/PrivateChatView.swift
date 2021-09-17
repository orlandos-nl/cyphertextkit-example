//
//  PrivateChat.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import Combine
import SwiftUI
import CypherMessaging
import MessagingHelpers

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
                            MessageCell(message: message)
                                .id(message.id)
                        }
                        
                        // Replaces padding bottom
                        Color(white: 0, opacity: 0.001).frame(height: 12).id("bottom")
//                        #if os(iOS)
//                            .onReceive(Keyboard.main.$isShown) { isShown in
//                                withAnimation {
//                                    proxy.scrollTo("bottom")
//                                }
//                            }
//                        #endif
                    }.padding(.top, 12).onReceive(plugin.savedChatMessages) { message in
                        if case .otherUser(chat.conversationPartner) = message.target {
                            messages.insert(message, at: 0)
                            proxy.scrollTo("bottom")
                        }
                    }.onReceive(plugin.chatMessageRemoved) { message in
                        if case .otherUser(chat.conversationPartner) = message.target {
                            for i in 0..<messages.count {
                                if message.id == messages[i].id {
                                    messages.remove(at: i)
                                    return
                                }
                            }
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
            #if os(iOS)
            .navigationBarTitle(contact.nickname, displayMode: .inline)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIViewController.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            #endif
            
            Divider()
            
            Group {
                if contact.isBlocked {
                    Text("Contact is Blocked").foregroundColor(.gray)
                } else if contact.isMutualFriendship {
                    ChatBar(
                        chat: chat,
                        recorder: VoiceRecorder(messenger: messenger),
                        indicator: .init(chat: chat, emitter: plugin)
                    )
                } else if contact.ourState == .friend {
                    VStack {
                        Text("Contact Request Pending")
                        
                        Button("Resend Request") {
                            Task.detached {
                                try await contact.befriend()
                                try await contact.query()
                            }
                        }
                    }.padding()
                } else {
                    VStack {
                        Text("Contact Requested Contact")
                        
                        HStack {
                            Button("Accept") {
                                Task.detached {
                                    try await contact.befriend()
                                    id = UUID()
                                }
                            }
                            
                            Button("Ignore", role: nil) {
                                Task.detached {
                                    try await contact.unfriend()
                                    presentationMode.wrappedValue.dismiss()
                                }
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
        }.background {
            #if os(macOS)
            Color.white
            #endif
        }.navigationTitle(contact.nickname)
    }
}
