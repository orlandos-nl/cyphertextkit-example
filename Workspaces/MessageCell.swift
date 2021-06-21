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
                }.contextMenu {
                    Button {
                        UIPasteboard.general.string = message.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
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
            case .media where message.messageSubtype == "image/*":
                imageView
            case .magic, .media:
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
    
    @ViewBuilder var imageView: some View {
        if
            let binary = message.metadata["blob"] as? Binary,
            let image = Image(data: binary.data)
        {
            if
                let binary = message.metadata["thumbnail"] as? Binary,
                let thumbnail = Image(data: binary.data)
            {
                NavigationLink(destination: {
                    ImageViewer(image: image)
                }) {
                    box {
                        thumbnail
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 250)
                            .drawingGroup()
                    }.fullSized()
                }
            } else {
                NavigationLink(destination: {
                    ImageViewer(image: image)
                }) {
                    box {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 250)
                            .drawingGroup()
                    }.fullSized()
                }
            }
        }
    }
    
    func box<V: View>(@ViewBuilder build: () -> V) -> MessageBox<V> {
        MessageBox(
            isWrittenByMe: isWrittenByMe,
            metadata: metadata,
            contents: build()
        )
    }
}

struct MessageBox<V: View>: View {
    let isWrittenByMe: Bool
    let metadata: Text
    let contents: V
    var isFullSized = false
    
    public func fullSized() -> MessageBox<V> {
        var copy = self
        copy.isFullSized = true
        return copy
    }
    
    @ViewBuilder var body: some View {
        if isFullSized {
            ZStack(alignment: isWrittenByMe ? .bottomTrailing : .bottomLeading) {
                contents
                
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0.8), location: 0),
                        .init(color: Color.black.opacity(0.0), location: 0.2)
                    ]),
                    startPoint: .bottomTrailing,
                    endPoint: .init(x: 0.7, y: 0)
                ).cornerRadius(8)
                
                metadata
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.white)
                    .padding(5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 8)
        } else {
            ZStack(alignment: isWrittenByMe ? .bottomTrailing : .bottomLeading) {
                contents
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
}
