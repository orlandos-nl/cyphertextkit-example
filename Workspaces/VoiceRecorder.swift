import SwiftUI
import SwiftUIX
import AVFoundation
import NIO
import CypherMessaging

final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    let session = AVAudioSession.sharedInstance()
    let messenger: CypherMessenger
    let id = UUID()
    let recorder: AVAudioRecorder
    @Published private(set) var started = false
    @Binding var soundSample: Float
    let url: URL
    @Binding var isRecording: Bool
    let onRecording: (Data) async throws -> ()
    private var cancelled = false
    private(set) var startDate: Date?
    private(set) var length: TimeInterval?
    
    init?(
        messenger: CypherMessenger,
        isRecording: Binding<Bool>,
        soundSample: Binding<Float>,
        onRecording: @escaping (Data) async throws -> ()
    ) {
        self.onRecording = onRecording
        self.messenger = messenger
        self._isRecording = isRecording
        self._soundSample = soundSample
        
        do {
            self.url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("\(id.uuidString).av")
            
            let recorderSettings: [String:Any] = [
                AVFormatIDKey: NSNumber(value: kAudioFormatAppleLossless),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]
            
            self.recorder = try AVAudioRecorder(url: url, settings: recorderSettings)
            
            super.init()
            
            self.recorder.prepareToRecord()
            self.recorder.isMeteringEnabled = true
            self.recorder.delegate = self
        } catch {
            return nil
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully: Bool) {
        if cancelled {
            return
        }
        
        if let length = self.length, length <= 1.5 {
            isRecording = false
            started = false
            return
        }
        
        if successfully {
            do {
                let data = try Data(contentsOf: self.url)
                
                detach {
                    try await self.onRecording(data)
                }
                
                try FileManager.default.removeItem(at: self.url)
                try Data().write(to: self.url, options: .completeFileProtection)
            } catch {}
        }
    }
    
    func refresh() {
        guard let startDate = startDate else { return }
        
        if abs(startDate.timeIntervalSinceNow) >= 60 {
            return stop()
        }
        
        recorder.updateMeters()
        soundSample = recorder.averagePower(forChannel: 0)
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) { [weak self] in
            self?.refresh()
        }
    }
    
    func start() async -> Bool {
        if session.recordPermission == .denied {
            return false
        }
        
        func run() -> Bool {
            do {
                try self.session.setActive(true)
            } catch {
                return false
            }
            
            if self.recorder.record() {
                self.length = nil
                self.started = true
                self.isRecording = true
                self.startDate = Date()
                self.refresh()
                return true
            } else {
                return false
            }
        }
        
        if session.recordPermission == .undetermined {
            let promise = messenger.eventLoop.makePromise(of: Bool.self)
            session.requestRecordPermission { success in
                if success {
                    promise.succeed(run())
                } else {
                    promise.succeed(false)
                }
            }
            return try! await promise.futureResult.get()
        }
        
        return run()
    }
    
    func stop() {
        if started {
            length = startDate.map { date in
                abs(date.timeIntervalSinceNow)
            }
            startDate = nil
            started = false
            isRecording = false
            recorder.stop()
        }
    }
    
    func cancel() {
        cancelled = true
        stop()
    }
    
    deinit {
        isRecording = false
        recorder.stop()
    }
}
