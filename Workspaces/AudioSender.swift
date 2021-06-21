//
//  AudioSender.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 15/06/2021.
//

import SwiftUI
import CypherMessaging

struct AudioSender<Chat: AnyConversation>: View {
    let audio: Data
    let chat: Chat
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    if let player = AudioPlayer(audio: audio) {
                        MessageBox(
                            isWrittenByMe: true,
                            metadata: Text("Now"),
                            contents: PlayAudioView(player: player, foregroundColor: Color(white: 0.4))
                                .padding(.top, 12)
                        )
                    } else {
                        Text("Invalid Audio Segment")
                            .foregroundColor(.red)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                                    self.presentationMode.dismiss()
                                }
                            }
                    }
                }
                
                Spacer()
                
                Button("Send", role: nil) {
                    do {
                        _ = try await chat.sendRawMessage(
                            type: .media,
                            messageSubtype: "audio",
                            text: "",
                            metadata: [
                                "blob": audio
                            ],
                            preferredPushType: .message
                        )
                        
                        self.presentationMode.dismiss()
                    } catch {
                        // TODO:
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(RoundedBorderButtonStyle(fill: Color(white: 0.97)))
                
                Button("Cancel") {
                    self.presentationMode.dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.red)
                .buttonStyle(RoundedBorderButtonStyle(fill: Color(white: 0.97)))
            }
            .padding(16)
            .navigationBarTitle("Send Voice Message", displayMode: .inline)
        }
    }
}
