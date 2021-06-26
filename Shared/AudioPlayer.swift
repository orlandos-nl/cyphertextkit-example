//
//  AudioPlayer.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 15/06/2021.
//

import AVFoundation
import SwiftUI

final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private let player: AVAudioPlayer
    @Published var playing = false
    private(set) static var playingSounds = false
    
    var currentTime: TimeInterval {
        get { player.currentTime }
        set { player.currentTime = newValue }
    }
    
    var duration: TimeInterval {
        get { player.duration }
        set { }
    }
    
    init?(audio: Data) {
        do {
            player = try AVAudioPlayer(data: audio)
            player.prepareToPlay()
            super.init()
            
            player.delegate = self
        } catch {
            return nil
        }
    }
    
    func play() {
        #if os(iOS)
        _ = try? AVAudioSession.sharedInstance().setCategory(.playback)
        #endif
        playing = true
        player.play()
        emitPlayChange()
        Self.playingSounds = true
    }
    
    private func emitPlayChange() {
        assert(Thread.isMainThread, "UI updates triggering from non-main thread")
        
        if !playing {
            return
        }
        
        self.objectWillChange.send()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1), execute: emitPlayChange)
    }
    
    func pause() {
        player.pause()
        playing = false
    }
    
    func stop() {
        player.stop()
        playing = false
    }
    
    func forward(by interval: TimeInterval) {
        player.currentTime = max(player.currentTime + interval, 0)
    }
    
    func disappear() {
        player.delegate = nil
        stop()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playing = false
        Self.playingSounds = false
    }
    
    deinit {
        Self.playingSounds = false
        player.delegate = nil
        player.stop()
    }
}
