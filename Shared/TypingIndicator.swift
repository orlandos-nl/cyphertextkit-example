import Combine
import SwiftUI
import SwiftUIX
import CypherMessaging
import MessagingHelpers

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
        Task.detached {
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
            
            Task.detached {
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
            
            Task.detached {
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
        Task.detached {
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
