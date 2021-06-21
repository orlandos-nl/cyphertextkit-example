//
//  ChatBar.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/06/2021.
//

import SwiftUI
import CypherMessaging
import MessagingHelpers

struct ChatBar<Chat: AnyConversation>: View {
    let chat: Chat
    @State var message = ""
    @State var sendAttachment = false
    @State var isRecording = false
    @State var recorder: VoiceRecorder?
    @State var soundSample: Float = 0
    @State var recordedAudio: Data? = nil
    @State var sendPhoto = false
    @StateObject var indicator: TypingIndicator
    @Environment(\.messenger) var messenger
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if let typingContact = indicator.typingContacts.first {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                    
                    Text("\(typingContact.nickname) is typing..")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                // 16 = leading spacing, 36 = button, 8 = input spacing, 12 = a nice inset
                // -4 = circle, -2 = spacing
            }.padding(.leading, 66).frame(height: 12)
            
            HStack(alignment: .top, spacing: 8) {
                Menu {
                    Button("Photo") {
                        sendPhoto = true
                    }
                } label: {
                    Circle()
                        .foregroundColor(Color(white: 0.95))
                        .overlay {
                            Image(systemName: "paperclip")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 36, height: 36)
                }.fullScreenCover(isPresented: $sendPhoto) {
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
                        
                        detach {
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
                
                ExpandingTextView(
                    "Message",
                    text: $message,
                    heightRange: 16..<80,
                    isDisabled: $isRecording
                ).onChange(of: message) { message in
                    detach {
                        await indicator.emitIsTyping(!message.isEmpty)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.95)))
                
                Button(role: nil) {
                    do {
                        if message.isEmpty {
                            if isRecording {
                                recorder?.stop()
                                isRecording = false
                            } else {
                                detach {
                                    if await recorder?.start() == true {
                                        DispatchQueue.main.async {
                                            isRecording = true
                                        }
                                    }
                                }
                            }
                        } else {
                            let message = self.message
                            self.message = ""
                            try await chat.sendRawMessage(type: .text, text: message, preferredPushType: .message)
                        }
                    } catch {}
                } label: {
                    Circle()
                        .foregroundColor(isRecording ? .red : Color(white: 0.95))
                        .padding(isRecording ? -normalisedSoundLevel : 0)
                        .animation(.easeInOut, value: soundSample)
                        .overlay(
                            ZStack {
                                Image(
                                    systemName: message.isEmpty ? "mic.fill" : "paperplane.fill"
                                ).foregroundColor(buttonColor)
                            
                                if isRecording, let startDate = recorder?.startDate {
                                    AutoUpdatingTimeLabel(startDate: startDate)
                                        .foregroundColor(.white)
                                        .padding(.top, 28)
                                }
                            }
                        )
                }.frame(width: 36, height: 36).sheet(isPresented: $recordedAudio.isNotNil()) {
                    if let audio = recordedAudio {
                        AudioSender(audio: audio, chat: chat)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }.onAppear {
            recorder = VoiceRecorder(
                messenger: messenger,
                isRecording: $isRecording,
                soundSample: $soundSample
            ) { data in
                self.recordedAudio = data
            }
        }
    }
    
    var normalisedSoundLevel: CGFloat {
        let level = max(0, CGFloat(soundSample) + 50) / 2 // between 0.1 and 25
        
        return CGFloat(level + 4)// * (24 / 25)) + 4 // scaled to max at 16 (our desired max stretching of the record button) + minimum sizing
    }
    
    var buttonColor: Color {
        if isRecording {
            return .white
        } else if message.isEmpty {
            return .gray
        } else {
            return .accentColor
        }
    }
}

struct AutoUpdatingTimeLabel: View {
    let startDate: Date
    @StateObject var tick = AutoSignal(interval: .seconds(1))
    
    var timeString: String {
        let seconds = abs(Int(startDate.timeIntervalSinceNow))
        
        if seconds < 10 {
            return "0\(seconds)"
        } else if seconds < 60 {
            return String(seconds)
        } else {
            let minutes = seconds % 60
            let seconds = seconds - (minutes * 60)
            
            if seconds < 10 {
                return "\(minutes):0\(seconds)"
            } else {
                return "\(minutes):\(seconds)"
            }
        }
    }
    
    var body: some View {
        Text(timeString)
            .font(.system(size: 10, design: .monospaced))
    }
}
