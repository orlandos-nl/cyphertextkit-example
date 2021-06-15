//import MessagingHelpers
//import NIO
//import Combine
//import SwiftUI
//import CypherMessaging
//
//enum MessengerError: Error {
//    case locked
//}
//
//extension PrivateChat: Hashable {
//    public func hash(into hasher: inout Hasher) {
//        id.hash(into: &hasher)
//    }
//    
//    public static func ==(lhs: PrivateChat, rhs: PrivateChat) -> Bool {
//        lhs.id == rhs.id
//    }
//}
//
//extension Array {
//    func lastActivitySorted() -> [Element] where Element: AnyConversation {
//        self.sorted { lhs, rhs in
//            switch (lhs.lastActivity, rhs.lastActivity) {
//            case (.some(let lhs), .some(let rhs)):
//                return lhs > rhs
//            case (.some, .none):
//                return true
//            case (.none, .some):
//                return false
//            case (.none, .none):
//                return true
//            }
//        }
//    }
//}
//
//final class Chats: ObservableObject {
//    @Published private var allConversations: [TargetConversation.Resolved]
//    public private(set) var privateChats = [PrivateChat]()
//    
//    func update(to allConversations: [TargetConversation.Resolved]) async {
//        self.allConversations = allConversations
//        self.resort()
//    }
//    
//    private func resort() {
//        privateChats = allConversations.compactMap { chat -> PrivateChat? in
//            switch chat {
//            case .privateChat(let chat):
//                return chat
//            case .internalChat, .groupChat:
//                return nil
//            }
//        }.lastActivitySorted()
//    }
//    
//    init(allConversations: [TargetConversation.Resolved]) {
//        self._allConversations = .init(initialValue: allConversations)
//        resort()
//    }
//}
//
//final class Messenger: ObservableObject {
//    @Published private(set) var locked = false
//    private(set) var messenger: CypherMessenger!
//    private(set) var store: SQLiteStore?
//    let eventLoop: EventLoop
//    let chats: Chats
//    private(set) var username: Username?
//    @Published private(set) var destroyed = false
//    public let savedChatMessages = PassthroughSubject<AnyChatMessage, Never>()
//    
//    convenience init(messenger: CypherMessenger) async throws {
//        try await self.init(optionalMessenger: messenger)
//    }
//    
//    convenience init() async throws {
//        try await self.init(optionalMessenger: nil)
//    }
//    
//    private init(optionalMessenger: CypherMessenger?) async throws {
//        self.messenger = optionalMessenger
//        self.eventLoop = optionalMessenger?.eventLoop ?? MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
//        self.chats = Chats(allConversations: [])
//        
//        if let optionalMessenger = optionalMessenger {
//            try await refreshConversationCaches()
//            self.username = optionalMessenger.username
//        }
//    }
//    
//    func setMessenger(to messenger: CypherMessenger, store: SQLiteStore) async throws {
//        self.messenger = messenger
//        self.store = store
//        
//        try await refreshConversationCaches()
//        self.username = messenger.username
//    }
//    
//    func listPrivateChats() -> EventLoopFuture<[PrivateChat]> {
//        
//        guard let messenger = messenger else {
//            return eventLoop.makeFailedFuture(MessengerError.locked)
//        }
//        
//        return messenger.listPrivateChats { lhs, rhs in
//            let lhsMetadata = try BSONDecoder().decode(
//                PrivateChatMetadata.self,
//                from: lhs.conversation.metadata
//            )
//            
//            let rhsMetadata = try BSONDecoder().decode(
//                PrivateChatMetadata.self,
//                from: rhs.conversation.metadata
//            )
//            
//            switch (lhsMetadata.lastActivity, rhsMetadata.lastActivity) {
//            case (.some(let lhs), .some(let rhs)):
//                return lhs > rhs
//            case (.none, .some):
//                // Right (.some) comes first
//                return false
//            case (.some, .none):
//                // Left (.some) comes first
//                return true
//            case (.none, .none):
//                // < = ascending usernames
//                let lhsName = lhsMetadata.nickname ?? lhs.conversationPartner.raw
//                let rhsName = rhsMetadata.nickname ?? rhs.conversationPartner.raw
//                return lhsName.lowercased() < rhsName.lowercased()
//            }
//        }
//    }
////
////    public func onCreateChatMessage(_ message: AnyChatMessage) {
////        self.savedChatMessages.send(message)
////    }
////
//    private func refreshConversationCaches() async throws {
//        let conversations = try await self.messenger.listConversations(includingInternalConversation: false) { lhs, rhs in
//            return true
//        }
//
//        await self.chats.update(to: conversations)
//    }
//    
//    public func lock() {
//        self.messenger = nil
//    }
//    
//    public func destroy() throws {
//        if !locked, let store = store {
//            lock()
//            self.destroyed = true
//            store.destroy()
//        } else {
//            throw MessengerError.locked
//        }
//    }
//}
