//
//  MessageCell.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 19/04/2021.
//

import SwiftUI
import CypherMessaging
import UniformTypeIdentifiers

extension UTType {
    init(filename: String) {
        if
            let fileExtension = filename.split(separator: ".").last,
            let type = UTType(filenameExtension: String(fileExtension))
        {
            self = type
        } else {
            self = .data
        }
    }
}

struct SharedFile: FileDocument {
    private static var supportedContentTypes: Set<UTType> = [ .item, .content, .data ]
    
    static var readableContentTypes: [UTType] { Array(supportedContentTypes) }
    static var writableContentTypes: [UTType] { Array(supportedContentTypes) }
    
    let data: Data
    let filename: String?
    init(configuration: ReadConfiguration) throws {
        struct InvalidFile: Error {}
        guard let data = configuration.file.regularFileContents else {
            throw InvalidFile()
        }
        self.data = data
        self.filename = configuration.file.preferredFilename
        
        if let filename = self.filename {
            SharedFile.supportedContentTypes.insert(UTType(filename: filename))
        }
    }
    
    init(data: Data, filename: String?) {
        self.data = data
        self.filename = filename
        if let filename = filename {
            SharedFile.supportedContentTypes.insert(UTType(filename: filename))
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = filename
        wrapper.filename = filename
        return wrapper
    }
}

struct MessageCell: View {
    @Environment(\.messenger) var messenger
    @Environment(\.plugin) var plugin
    @State var message: AnyChatMessage
    @State var action = false
    
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
                    RichText(message.text)
                    #if os(macOS)
                        .textSelection(.enabled)
                    #endif
                }.contextMenu {
                    #if os(iOS)
                    Button {
                        UIPasteboard.general.string = message.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    #endif
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
            case .media where message.messageSubtype == "any":
                if
                    let name = message.metadata["name"] as? String,
                    let blob = message.metadata["blob"] as? Binary
                {
                    box {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(name)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.accentColor)
                                
                                Text(NSNumber(value: blob.count), formatter: ByteCountFormatter())
                                    .foregroundColor(.gray)
                            }
                        }.padding(8)
                    }.onTapGesture {
                        action = true
                    }.fileExporter(
                        isPresented: $action,
                        document: SharedFile(
                            data: blob.data,
                            filename: name
                        ),
                        contentType: UTType(filename: name),
                        defaultFilename: name,
                        onCompletion: { _ in }
                    )
                }
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
                box {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 250)
                        .drawingGroup()
                }.fullSized()
            } else {
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
