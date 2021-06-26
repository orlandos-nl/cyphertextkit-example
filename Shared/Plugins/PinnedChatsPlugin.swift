//
//  PinnedChatsPlugin.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 15/06/2021.
//

import CypherMessaging
import MessagingHelpers
import SwiftUI

private struct ChatMetadata: Codable {
    var isPinned: Bool?
    var isMarkedUnread: Bool?
}

struct PinnedChatsPlugin: Plugin {
    static let pluginIdentifier = "pinned-chats"
    
    func createPrivateChatMetadata(withUser otherUser: Username, messenger: CypherMessenger) async throws -> Document {
        try BSONEncoder().encode(ChatMetadata(isPinned: false, isMarkedUnread: false))
    }
}

extension AnyConversation {
    public var isPinned: Bool {
        (try? self.conversation.getProp(
            ofType: ChatMetadata.self,
            forPlugin: PinnedChatsPlugin.self,
            run: \.isPinned
        )) ?? false
    }
    
    public var isMarkedUnread: Bool {
        (try? self.conversation.getProp(
            ofType: ChatMetadata.self,
            forPlugin: PinnedChatsPlugin.self,
            run: \.isMarkedUnread
        )) ?? false
    }
    
    public func pin() async throws {
        try await modifyMetadata(
            ofType: ChatMetadata.self,
            forPlugin: PinnedChatsPlugin.self
        ) { metadata in
            metadata.isPinned = true
        }
    }
    
    public func unpin() async throws {
        try await modifyMetadata(
            ofType: ChatMetadata.self,
            forPlugin: PinnedChatsPlugin.self
        ) { metadata in
            metadata.isPinned = false
        }
    }
    
    public func markUnread() async throws {
        try await modifyMetadata(
            ofType: ChatMetadata.self,
            forPlugin: PinnedChatsPlugin.self
        ) { metadata in
            metadata.isMarkedUnread = true
        }
    }
    
    public func unmarkUnread() async throws {
        try await modifyMetadata(
            ofType: ChatMetadata.self,
            forPlugin: PinnedChatsPlugin.self
        ) { metadata in
            metadata.isMarkedUnread = false
        }
    }
}
