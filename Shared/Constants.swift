import SwiftUI
import NIO
import CypherMessaging
import MessagingHelpers

func sortConversations(lhs: TargetConversation.Resolved, rhs: TargetConversation.Resolved) -> Bool {
    switch (lhs.isPinned, rhs.isPinned) {
    case (true, true), (false, false):
        ()
    case (true, false):
        return true
    case (false, true):
        return false
    }
    
    switch (lhs.lastActivity, rhs.lastActivity) {
    case (.some(let lhs), .some(let rhs)):
        return lhs > rhs
    case (.some, .none):
        return true
    case (.none, .some):
        return false
    case (.none, .none):
        return true
    }
}

func makeEventEmitter() -> SwiftUIEventEmitter {
    SwiftUIEventEmitter(sortChats: sortConversations)
}

func makeP2PFactories() -> [P2PTransportClientFactory] {
    return [
        IPv6TCPP2PTransportClientFactory()
    ]
}

func makeEventHandler(emitter: SwiftUIEventEmitter) -> PluginEventHandler {
    PluginEventHandler(plugins: [
        FriendshipPlugin(ruleset: {
            var ruleset = FriendshipRuleset()
            ruleset.ignoreWhenUndecided = true
            ruleset.preventSendingDisallowedMessages = true
            return ruleset
        }()),
        UserProfilePlugin(),
        ChatActivityPlugin(),
        SwiftUIEventEmitterPlugin(emitter: emitter),
    ])
}

enum Constants {
    static let host = "chat-api.orlandos.nl"
}
