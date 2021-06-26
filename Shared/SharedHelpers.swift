import CypherMessaging

extension PrivateChat: Identifiable {
    public var id: UUID { self.conversation.id }
}

extension GroupChat: Identifiable {
    public var id: UUID { self.conversation.id }
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
