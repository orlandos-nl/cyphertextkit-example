//
//  MessageCell.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 19/04/2021.
//

import SwiftUI
import CypherMessaging

struct MessageCell: View {
    @Environment(\.messenger) var messenger
    @Environment(\.plugin) var plugin
    @State var message: AnyChatMessage
    
    var isWrittenByMe: Bool {
        message.raw.senderUser == messenger.username
    }
    
    var readerState: Text {
        switch message.raw.deliveryState {
        case .revoked:
            return Text(Image(systemName: "trash.circle"))
        case .none:
            return Text(Image(systemName: "circle"))
        case .undelivered:
            return Text(Image(systemName: "xmark.circle"))
        case .received:
            return Text(Image(systemName: "checkmark.circle"))
        case .read:
            return Text(Image(systemName: "checkmark.circle.fill"))
        }
    }
    
    var metadata: Text {
        if isWrittenByMe {
            return Text(date: message.raw.sendDate, requiresTime: true) + Text(" ") + readerState
        } else {
            return Text(date: message.raw.sendDate, requiresTime: true)
        }
    }
    
    @ViewBuilder var body: some View {
        HStack {
            if isWrittenByMe || message.messageType == .magic {
                Spacer(minLength: 100)
            }
            
            switch message.messageType {
            case .text:
                box {
                    Text(message.text)
                }
            case .media where message.messageSubtype == "audio":
                if
                    let binary = message.metadata["blob"] as? Binary,
                    let player = AudioPlayer(audio: binary.data)
                {
                    box {
                        PlayAudioView(player: player, foregroundColor: Color(white: 0.4))
                            .padding(.top, 12)
                    }
                }
            case .media:
                box {
                    Text("<Media>")
                }
            case .magic:
                EmptyView()
            }
            
            if !isWrittenByMe || message.messageType == .magic {
                Spacer(minLength: 100)
            }
        }.task {
            _ = try? await message.markAsRead()
        }.onReceive(plugin.chatMessageChanged) { changedMessage in
            if changedMessage.id == self.message.id {
                self.message = changedMessage
            }
        }
    }
    
    func box<V: View>(@ViewBuilder build: () -> V) -> some View {
        ZStack(alignment: isWrittenByMe ? .bottomTrailing : .bottomLeading) {
            build()
                .padding(.bottom, 14)
            
            metadata
                .font(.system(size: 10, weight: .light))
                .foregroundColor(.gray)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isWrittenByMe ? Color(white: 0.97) : Color(white: 0.95))
        ).padding(.horizontal, 8)
    }
}
