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
    @State var isRecording = false
    @StateObject var recorder: VoiceRecorder
    @State var soundSample: Float = 0
    @State var recordedAudio: Data? = nil
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
                if let recordedAudio = recordedAudio {
                    Circle()
                        .foregroundColor(Color(white: 0.95))
                        .overlay {
                            Image(systemName: "trash")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 36, height: 36)
                        .onTapGesture {
                            self.recordedAudio = nil
                        }
                    
                    if let player = AudioPlayer(audio: recordedAudio) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(white: 0.95))
                            .frame(height: 36)
                            .overlay(alignment: .leading) {
                                PlayButton(player: player)
                            }.overlay {
                                VoiceWave(
                                    samples: recorder.allSamples,
                                    color: Color(white: 0.65),
                                    highlightColor: .accentColor,
                                    player: player,
                                    minSample: recorder.lowestSoundSample ?? 0,
                                    maxSample: recorder.highestSoundSample ?? 0,
                                    minHeight: 2,
                                    maxHeight: 26
                                )
                                .padding(.leading, 36 + 8)
                                .padding(.trailing, 12)
                            }
                    } else {
                        ProgressView().onAppear {
                            self.recordedAudio = nil
                        }
                    }
                } else {
                    AttachmentButton(chat: chat)
                    
                    #if os(iOS)
                    ExpandingTextView(
                        isRecording ? "Recording.." : "Message",
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
                    #else
                    TextField(isRecording ? "Recording.." : "Message", text: $message)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: message) { message in
                        detach {
                            await indicator.emitIsTyping(!message.isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.95)))
                    #endif
                }
                
                Button(role: nil, action: send) {
                    Circle()
                        .foregroundColor(isRecording ? .red : Color(white: 0.95))
                        .padding(isRecording ? recordingCirclePadding : 0)
                        .animation(.easeInOut, value: soundSample)
                        .overlay(
                            ZStack {
                                Image(
                                    systemName: recordedAudio == nil && message.isEmpty ? "mic.fill" : "paperplane.fill"
                                ).foregroundColor(buttonColor)
                            
                                if isRecording, let startDate = recorder.startDate {
                                    AutoUpdatingTimeLabel(startDate: startDate)
                                        .foregroundColor(.white)
                                        .padding(.top, 28)
                                }
                            }
                        )
                }
                .frame(width: 36, height: 36)
                .buttonStyle(PlainButtonStyle())
                .onKeyboardShortcut(.return, modifiers: .command, perform: send)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }.onAppear {
            recorder.configure(
                isRecording: $isRecording,
                soundSample: $soundSample
            ) { data in
                self.recordedAudio = data
            }
        }
    }
    
    private func send() {
        if let audio = recordedAudio {
            self.recordedAudio = nil
            detach {
                try await chat.sendRawMessage(
                    type: .media,
                    messageSubtype: "audio",
                    text: "",
                    metadata: [
                        "blob": audio
                    ],
                    preferredPushType: .message
                )
            }
        } else if message.isEmpty {
            if isRecording {
                recorder.stop()
                isRecording = false
            } else {
                detach {
                    if await recorder.start() == true {
                        DispatchQueue.main.async {
                            isRecording = true
                        }
                    }
                }
            }
        } else {
            sendText()
        }
    }
    
    private func sendText() {
        if message.isEmpty { return }
        
        let message = self.message
        self.message = ""
        detach {
            try await chat.sendRawMessage(type: .text, text: message, preferredPushType: .message)
        }
    }
    
    var normalisedRelativeSoundLevel: Float {
        if
            let lowestSoundSample = recorder.lowestSoundSample,
            let highestSoundSample = recorder.highestSoundSample
        {
            let relativeSoundSample = soundSample - lowestSoundSample
            let relativeUpperBound = highestSoundSample - lowestSoundSample
            if relativeSoundSample == 0 {
                return 0
            }
            
            return relativeSoundSample / relativeUpperBound
        } else {
            return 0
        }
    }
    
    var recordingCirclePadding: CGFloat {
        let level = -CGFloat((normalisedRelativeSoundLevel * 16) - 2)
        if !level.isFinite {
            return 0
        }
        
        return level
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

struct RichText: View {
    let body: Text
    
    init(_ input: String) {
        do {
            let string = try AttributedString(
                markdown: input,
                including: \.workspaces
            )
            
            self.body = Text(string)
        } catch {
            self.body = Text(input)
        }
    }
}

extension AttributeScopes {
    struct WorkspacesScope: AttributeScope {
        let swiftUI: SwiftUIAttributes
    }
    
    var workspaces: WorkspacesScope.Type { WorkspacesScope.self }
}

struct PlayButton: View {
    @StateObject var player: AudioPlayer
    
    var body: some View {
        Circle()
            .foregroundColor(Color(white: 0.92))
            .overlay {
                Image(systemName: player.playing ? "pause.fill" : "play.fill")
                    .foregroundColor(Color(white: 0.15))
            }
            .frame(width: 36, height: 36)
            .onTapGesture {
                if player.playing {
                    player.pause()
                } else {
                    player.play()
                }
            }.onDisappear {
                player.stop()
            }
    }
}

struct VoiceWave: View {
    let samples: [Float]
    let color: Color
    let highlightColor: Color
    let player: AudioPlayer
    @StateObject var tick = AutoSignal(interval: .microseconds(250))
    let minSample: Float
    let maxSample: Float
    let minHeight: CGFloat
    let maxHeight: CGFloat
    var range: Range<Float> {
        minSample..<maxSample
    }
    
    var body: some View {
        GeometryReader { reader in
            HStack(spacing: 1) {
                ForEach(Array(subSamples(count: Int(reader.size.width / 5)).enumerated()), id: \.0) { sample in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isHighlighted(sample.offset, maxOffset: Int(reader.size.width / 5)) ? highlightColor : color)
                        .frame(
                            width: 4,
                            height: height(forSample: sample.element, inRange: range)
                        ).onTapGesture {
                            let offset = sample.offset
                            let maxOffset =  Int(reader.size.width / 5)
                            let fraction = Double(offset) / Double(maxOffset)
                            player.currentTime = player.duration * fraction
                        }
                }
            }
        }.frame(height: maxHeight)
    }
    
    func isHighlighted(_ offset: Int, maxOffset: Int) -> Bool {
        let active = player.duration / player.currentTime
        let activeOffset = Int(Double(maxOffset) / active)
        return offset <= activeOffset
    }
    
    func subSamples(count preferredCount: Int) -> [Float] {
        var samples = self.samples
        let sampleCount = samples.count
        
        if preferredCount <= 10 {
            return samples
        } else if sampleCount < preferredCount {
            return samples
        }
        
        let removedCount = sampleCount - preferredCount
        let spacing = removedCount / preferredCount
        var i = samples.count - 2
        
        while samples.count > preferredCount {
//            print(i, samples)
            samples.remove(at: i)
            i -= spacing
            
            if i <= 0 {
                i = samples.count - 2
            }
        }
        
        return samples
    }
    
    func height(forSample sample: Float, inRange range: Range<Float>) -> CGFloat {
        let diff = CGFloat(self.diff(forSample: sample, inRange: range))
        return (diff * (maxHeight - minHeight)) + minHeight
    }
    
    func diff(forSample sample: Float, inRange range: Range<Float>) -> Float {
        let offset = sample - range.lowerBound
        let rangeWidth = range.upperBound - range.lowerBound
        return offset / rangeWidth
    }
}
