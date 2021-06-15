//
//  PlayAudioButton.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 15/06/2021.
//

import SwiftUI

struct PlayAudioView: View {
    @StateObject var player: AudioPlayer
    @State var wasPlaying = false
    let foregroundColor: Color
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        HStack(alignment: .top) {
            if player.playing {
                Button(action: {
                    player.pause()
                    wasPlaying = false
                }) {
                    Image(systemName: "pause.fill")
                }
                .foregroundColor(foregroundColor)
                .frame(width: 44, height: 14)
            } else {
                Button(action: {
                    player.play()
                    wasPlaying = true
                }) {
                    Image(systemName: "play.fill")
                }
                .foregroundColor(foregroundColor)
                .frame(width: 44, height: 14)
            }
            
            RecordingProgressSlider(
                value: $player.currentTime,
                maxValue: $player.duration,
                onEditingChanged: { editing in
                    if wasPlaying {
                        if editing {
                            player.pause()
                        } else {
                            player.play()
                        }
                    }
                },
                foregroundColor: foregroundColor
            )
        }.frame(height: 16).onDisappear {
            player.stop()
        }.onDisappear {
            player.disappear()
        }
    }
}

struct RecordingProgressSlider: View {
    @Binding var value: Double
    @State var localValue: Double
    @State var swiping = false
    @Binding var maxValue: Double
    let onEditingChanged: (Bool) -> ()
    let foregroundColor: Color
    
    init(value: Binding<Double>, maxValue: Binding<Double>, onEditingChanged: @escaping (Bool) -> (), foregroundColor: Color) {
        self._value = value
        self._localValue = .init(wrappedValue: value.wrappedValue)
        self._maxValue = maxValue
        self.onEditingChanged = onEditingChanged
        self.foregroundColor = foregroundColor
    }
    
    var remoteFraction: Double {
        value / maxValue
    }
    
    var visibleFraction: Double {
        if swiping {
            return localValue / maxValue
        } else {
            return remoteFraction
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .frame(width: proxy.size.width, height: 4)
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: proxy.size.width * CGFloat(visibleFraction), height: 4)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().fill(foregroundColor).frame(width: 12, height: 12))
                    // - 7 is for half of the circle
                    .padding(.leading, (proxy.size.width * CGFloat(visibleFraction)) - 7)
                    .gesture(DragGesture(minimumDistance: 10, coordinateSpace: .global).onChanged { newValue in
                        onEditingChanged(true)
                        swiping = true
                        
                        let viewWidth = Double(proxy.size.width)
                        let xTranslation = Double(newValue.translation.width)
                        let xFraction = xTranslation / viewWidth
                        let newFraction = max(min(self.remoteFraction + xFraction, 1), 0)
                        let newValue = newFraction * maxValue
                        self.localValue = newValue
                    }.onEnded { newValue in
                        swiping = false
                        self.value = localValue
                        onEditingChanged(false)
                    })
            }
        }
    }
}
