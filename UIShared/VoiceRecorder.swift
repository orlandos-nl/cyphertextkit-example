import SwiftUI
import AVFoundation
import NIO
import CypherMessaging

final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    #if os(iOS)
    let session = AVAudioSession.sharedInstance()
    #endif
    
    let messenger: CypherMessenger
    let id = UUID()
    let recorder: AVAudioRecorder
    let url: URL
    @Binding var isRecording: Bool
    @Published private(set) var started = false
    @Binding var soundSample: Float
    private(set) var lowestSoundSample: Float?
    private(set) var highestSoundSample: Float?
    private(set) var allSamples = [Float]()
    private var onRecording: (Data) async throws -> ()
    private var cancelled = false
    private(set) var startDate: Date?
    private(set) var length: TimeInterval?
    
    func configure(
        isRecording: Binding<Bool>,
        soundSample: Binding<Float>,
        onRecording: @escaping (Data) async throws -> ()
    ) {
        self._isRecording = isRecording
        self._soundSample = soundSample
        self.onRecording = onRecording
    }
    
    init(
        messenger: CypherMessenger
    ) {
        self.onRecording = { _ in }
        self.messenger = messenger
        self._isRecording = .constant(false)
        self._soundSample = .constant(0)
        
        do {
            self.url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("\(id.uuidString).av")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]
            
            self.recorder = try AVAudioRecorder(url: url, settings: settings)
            
            super.init()
            
            self.recorder.prepareToRecord()
            self.recorder.isMeteringEnabled = true
            self.recorder.delegate = self
        } catch {
            fatalError()
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
                
                Task.detached {
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
        allSamples.append(soundSample)
        if let lowestSoundSample = lowestSoundSample {
            if soundSample < lowestSoundSample {
                self.lowestSoundSample = soundSample
            }
        } else {
            self.lowestSoundSample = soundSample
        }
        if let highestSoundSample = highestSoundSample {
            if soundSample > highestSoundSample {
                self.highestSoundSample = soundSample
            }
        } else {
            self.highestSoundSample = soundSample
        }
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) { [weak self] in
            self?.refresh()
        }
    }
    
    func start() async -> Bool {
        func record() -> Bool {
            if self.recorder.record() {
                self.length = nil
                self.started = true
                self.isRecording = true
                self.startDate = Date()
                self.soundSample = 0
                self.lowestSoundSample = nil
                self.highestSoundSample = nil
                self.allSamples.removeAll(keepingCapacity: true)
                self.refresh()
                return true
            } else {
                return false
            }
        }
        
        #if os(iOS)
        if session.recordPermission == .denied {
            return false
        }
        
        func run() -> Bool {
            do {
                try self.session.setCategory(.playAndRecord)
                try self.session.setActive(true)
            } catch {
                return false
            }
            
            return record()
        }
        
        if session.recordPermission == .undetermined {
            return await withUnsafeContinuation { continuation in
                session.requestRecordPermission { success in
                    let result: Bool
                    if success {
                        result = run()
                    } else {
                        result = false
                    }
                    
                    continuation.resume(with: .success(result))
                }
            }
        }
        
        return run()
        #else
        return record()
        #endif
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
