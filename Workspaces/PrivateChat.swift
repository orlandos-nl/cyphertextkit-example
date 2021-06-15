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
                }.background(Color.almostClear.onTapGesture(perform: Keyboard.dismiss))
            }.navigationTitle(contact.username.raw)
            
            Divider()
            
            Group {
                if contact.isBlocked {
                    Text("Contact is Blocked").foregroundColor(.gray)
                } else if contact.isMutualFriendship {
                    ChatBar(chat: chat, indicator: .init(chat: chat, emitter: plugin))
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
                            id = UUID()
                        }
                    }.padding()
                }
            }.id(id)
        }.onReceive(plugin.contactChanged) { changedContact in
            if changedContact.id == contact.id {
                self.id = UUID()
            }
        }.onAppear {
            asyncDetached {
                messages += try await cursor.getMore(50)
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

struct ChatBar<Chat: AnyConversation>: View {
    let chat: Chat
    @State var message = ""
    @State var sendAttachment = false
    @State var isRecording = false
    @State var recorder: VoiceRecorder?
    @State var soundSample: Float = 0
    @State var recordedAudio: Data? = nil
    @StateObject var indicator: TypingIndicator
    @Environment(\.messenger) var messenger
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if let typingContact = indicator.typingContacts.first {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                    
                    Text("\(typingContact.nickname) is typing..")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                // 16 = leading spacing, 36 = button, 8 = input spacing, 12 = a nice inset
                // -4 = circle, -2 = spacing
            }.padding(.leading, 66).frame(height: 12)
            
            HStack(alignment: .top, spacing: 8) {
                Button {
                    sendAttachment = true
                } label: {
                    Circle()
                        .foregroundColor(Color(white: 0.95))
                        .overlay(Image(systemName: "paperclip").foregroundColor(.gray))
                }.frame(width: 36, height: 36).actionSheet(isPresented: $sendAttachment) {
                    ActionSheet(
                        title: Text("Send Attachment"),
                        buttons: [
                            .default(Text("Photo")),
                            .default(Text("File")),
//                            .default(Text("Poll")),
                            .cancel(Text("Cancel")),
                        ]
                    )
                }
                
                ExpandingTextView(
                    "Message",
                    text: $message,
                    heightRange: 16..<80,
                    isDisabled: $isRecording
                ).onChange(of: message) { message in
                    detach {
                        await indicator.emitIsTyping(!message.isEmpty)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.95)))
                
                Button(role: nil) {
                    do {
                        if message.isEmpty {
                            if isRecording {
                                recorder?.stop()
                                isRecording = false
                            } else {
                                detach {
                                    if await recorder?.start() == true {
                                        DispatchQueue.main.async {
                                            isRecording = true
                                        }
                                    }
                                }
                            }
                        } else {
                            let message = self.message
                            self.message = ""
                            try await chat.sendRawMessage(type: .text, text: message, preferredPushType: .message)
                        }
                    } catch {}
                } label: {
                    Circle()
                        .foregroundColor(isRecording ? .red : Color(white: 0.95))
                        .padding(isRecording ? -normalisedSoundLevel : 0)
                        .animation(.easeInOut, value: soundSample)
                        .overlay(
                            ZStack {
                                Image(
                                    systemName: message.isEmpty ? "mic.fill" : "paperplane.fill"
                                ).foregroundColor(buttonColor)
                            
                                if isRecording, let startDate = recorder?.startDate {
                                    AutoUpdatingTimeLabel(startDate: startDate)
                                        .foregroundColor(.white)
                                        .padding(.top, 28)
                                }
                            }
                        )
                }.frame(width: 36, height: 36).sheet(isPresented: $recordedAudio.isNotNil()) {
                    if let audio = recordedAudio {
                        AudioSender(audio: audio, chat: chat)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }.onAppear {
            recorder = VoiceRecorder(
                messenger: messenger,
                isRecording: $isRecording,
                soundSample: $soundSample
            ) { data in
                self.recordedAudio = data
            }
        }
    }
    
    var normalisedSoundLevel: CGFloat {
        let level = max(0, CGFloat(soundSample) + 50) / 2 // between 0.1 and 25
        
        return CGFloat(level + 4)// * (24 / 25)) + 4 // scaled to max at 16 (our desired max stretching of the record button) + minimum sizing
    }
    
    var buttonColor: Color {
        if isRecording {
            return .white
        } else if message.isEmpty {
            return .gray
        } else {
            return .accentColor
        }
    }
}

struct AutoUpdatingTimeLabel: View {
    let startDate: Date
    @StateObject var tick = AutoSignal(interval: .seconds(1))
    
    var timeString: String {
        let seconds = abs(Int(startDate.timeIntervalSinceNow))
        
        if seconds < 10 {
            return "0\(seconds)"
        } else if seconds < 60 {
            return String(seconds)
        } else {
            let minutes = seconds % 60
            let seconds = seconds - (minutes * 60)
            
            if seconds < 10 {
                return "\(minutes):0\(seconds)"
            } else {
                return "\(minutes):\(seconds)"
            }
        }
    }
    
    var body: some View {
        Text(timeString)
            .font(.system(size: 10, design: .monospaced))
    }
}
