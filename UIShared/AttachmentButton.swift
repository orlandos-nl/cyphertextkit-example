//
//  AttachmentButton.swift
//  iOS
//
//  Created by Joannis Orlandos on 26/06/2021.
//

import SwiftUI
import CypherMessaging

struct AttachmentButton<Chat: AnyConversation>: View {
    let chat: Chat
    @State var sendPhoto = false
    @State var sendAttachment = false
    
    #if os(iOS)
    var body: some View {
        Menu {
            Button("Photo") {
                sendPhoto = true
            }
        
            Button("File") {
                sendAttachment = true
            }
        } label: {
            Circle()
                .foregroundColor(Color(white: 0.95))
                .overlay {
                    Image(systemName: "paperclip")
                        .foregroundColor(.gray)
                }
                .frame(width: 36, height: 36)
        }
        .fileImporter(
            isPresented: $sendAttachment,
            allowedContentTypes: [
                .data
            ],
            onCompletion: { result in
                guard case .success(let url) = result else {
                    return
                }
            
                Task.detached {
                    let data = try Data(contentsOf: url)
                    try await chat.sendRawMessage(
                        type: .media,
                        messageSubtype: "any",
                        text: "",
                        metadata: [
                            "name": url.lastPathComponent,
                            "blob": data
                        ],
                        preferredPushType: .message
                    )
                }
            }
        )
        .fullScreenCover(isPresented: $sendPhoto) {
            ImagePicker(source: .savedPhotosAlbum) { image in
                sendPhoto = false
                
                guard
                    let image = image,
                    let jpeg = image.jpegData(compressionQuality: 0.8),
                    let thumbnail = image.resize(toTargetSize: CGSize(width: 300, height: 300)),
                    let thumbnailJpeg = thumbnail.jpegData(compressionQuality: 0.8)
                else {
                    return
                }
                
                Task.detached {
                    _ = try await chat.sendRawMessage(
                        type: .media,
                        messageSubtype: "image/*",
                        text: "",
                        metadata: [
                            "blob": jpeg,
                            "thumbnail": thumbnailJpeg
                        ],
                        preferredPushType: .message
                    )
                }
            }
        }
    }
    #else
    var body: some View {
        Circle()
            .foregroundColor(Color(white: 0.95))
            .overlay {
                Image(systemName: "paperclip")
                    .foregroundColor(.gray)
            }
            .frame(width: 36, height: 36)
            .onTapGesture {
                self.sendAttachment = true
            }
            .fileImporter(
                isPresented: $sendAttachment,
                allowedContentTypes: [
                    .data
                ],
                onCompletion: { result in
                    guard case .success(let url) = result else {
                        return
                    }
                    
                    Task.detached {
                        let data = try Data(contentsOf: url)
                        try await chat.sendRawMessage(
                            type: .media,
                            messageSubtype: "any",
                            text: "",
                            metadata: [
                                "name": url.lastPathComponent,
                                "blob": data
                            ],
                            preferredPushType: .message
                        )
                    }
                }
            )
    }
    #endif
}
