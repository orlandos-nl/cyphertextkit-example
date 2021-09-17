//import Logging
//import Foundation
//import WebRTC
//
//protocol WebRTCClientDelegate: AnyObject {
//    var canAcceptIceCandidates: Bool { get }
//    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
//    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
//    func webRTCClientDidConnect(_ client: WebRTCClient)
//    func webRTCClientDidDisconnect(_ client: WebRTCClient)
//    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
//}
//
//enum WebRTCError: Error {
//    case cannotAnswer, cannotOffer
//}
//
//final class WebRTCClient: NSObject {
//    
//    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
//    // A new RTCPeerConnection should be created every new call, but the factory is shared.
//    private static let factory: RTCPeerConnectionFactory = {
//        RTCInitializeSSL()
//        return RTCPeerConnectionFactory(encoderFactory: nil, decoderFactory: nil)
//    }()
//    
//    let bitrate: Int = 192_000
//    var delegate: WebRTCClientDelegate?
//    private var peerConnection: RTCPeerConnection
//    #if os(iOS)
//    private let rtcAudioSession = AVAudioSession()
//    #endif
//    public let logger = Logger(label: "nl.orlandos.workspaces.webrtc")
//    private let audioQueue = DispatchQueue(label: "audio")
//    private let mediaConstrains = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue]
//    private var localDataChannel: RTCDataChannel?
//    private var remoteDataChannel: RTCDataChannel?
//    private var discoveredICECandidateQueue = [RTCIceCandidate]()
//
//    @available(*, unavailable)
//    override init() {
//        fatalError("WebRTCClient:init is unavailable")
//    }
//    
//    func end() {
//        peerConnection.close()
//    }
//    
//    required init?(iceServers: [String], username: String, password: String) {
//        let config = RTCConfiguration()
//        config.iceServers = [
//            RTCIceServer(
//                urlStrings: iceServers,
//                username: username,
//                credential: password
//            )
//        ]
//        
//        // Unified plan is more superior than planB
//        config.sdpSemantics = .unifiedPlan
//        
//        // gatherContinually will let WebRTC to listen to any network changes and send any new candidates to the other client
//        config.continualGatheringPolicy = .gatherContinually
//        config.disableIPV6 = true
//        config.bundlePolicy = .maxBundle
//        config.rtcpMuxPolicy = .require
//        config.tcpCandidatePolicy = .disabled
//        
//        let constraints = RTCMediaConstraints(
//            mandatoryConstraints: nil,
//            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
//        )
//        
//        guard let peerConnection = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil) else {
//            return nil
//        }
//        
//        self.peerConnection = peerConnection
//        super.init()
//        self.createMediaSenders()
//        self.configureAudioSession()
//        self.peerConnection.delegate = self
//    }
//    
//    // MARK: Signaling
//    func offer() async throws -> String {
//        return try await withUnsafeThrowingContinuation { cont in
//            let constraints = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
//                                                 optionalConstraints: nil)
//            self.peerConnection.offer(for: constraints) { (sdp, error) in
//                if let error = error {
//                    cont.resume(throwing: error)
//                    return
//                }
//                
//                guard let sdp = sdp else {
//                    cont.resume(throwing: WebRTCError.cannotOffer)
//                    return
//                }
//                
//                self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
//                    if let error = error {
//                        cont.resume(throwing: error)
//                    } else {
//                        cont.resume(returning: self.setMediaBitrate(sdp: sdp.sdp, mediaType: "audio", bitrate: self.bitrate))
//                    }
//                })
//            }
//        }
//    }
//    
//    private func setMediaBitrate(sdp: String, mediaType: String, bitrate: Int) -> String {
//        var lines = sdp.components(separatedBy: "\n")
//        var line = -1
//        
//        for (index, lineString) in lines.enumerated() {
//            if lineString.hasPrefix("m=\(mediaType)") {
//                line = index
//                break
//            }
//        }
//        
//        guard line != -1 else {
//            // Couldn't find the m (media) line return the original sdp
//            logger.error("Couldn't find the m line in SDP so returning the original sdp")
//            return sdp
//        }
//        
//        // Go to next line i.e. line after m
//        line += 1
//        
//        // Now skip i and c lines
//        while (lines[line].hasPrefix("i=") || lines[line].hasPrefix("c=")) {
//            line += 1
//        }
//        
//        let newLine = "b=AS:\(bitrate)"
//        // Check if we're on b (bitrate) line, if so replace it
//        if lines[line].hasPrefix("b") {
//            logger.error("Replacing the b line of the SDP")
//            lines[line] = newLine
//        } else {
//            // If there's no b line, add a new b line
//            lines.insert(newLine, at: line)
//        }
//        
//        return lines.joined(separator: "\n")
//    }
//    
//    func answer() async throws -> RTCSessionDescription {
//        try await withUnsafeThrowingContinuation { cont in
//            let constrains = RTCMediaConstraints(
//                mandatoryConstraints: self.mediaConstrains,
//                optionalConstraints: nil
//            )
//            
//            self.peerConnection.answer(for: constrains) { (sdp, error) in
//                if let error = error {
//                    cont.resume(throwing: error)
//                    return
//                }
//                
//                guard let sdp = sdp else {
//                    cont.resume(throwing: WebRTCError.cannotAnswer)
//                    return
//                }
//                
//                self.peerConnection.setLocalDescription(
//                    sdp,
//                    completionHandler: { error in
//                        if let error = error {
//                            cont.resume(throwing: error)
//                        } else {
//                            cont.resume(returning: sdp)
//                        }
//                    }
//                )
//            }
//        }
//    }
//    
//    func set(remoteSdp: RTCSessionDescription) async throws {
//        return try await withUnsafeThrowingContinuation { cont in
//            self.peerConnection.setRemoteDescription(remoteSdp) { error in
//                if let error = error {
//                    cont.resume(throwing: error)
//                } else {
//                    cont.resume()
//                }
//            }
//        }
//    }
//    
//    func set(remoteCandidate: RTCIceCandidate) {
//        self.peerConnection.add(remoteCandidate) { error in
//            if let error = error {
//                self.logger.error("\(error)")
//            }
//        }
//    }
//    
//    private func configureAudioSession() {
//        #if os(iOS)
//        rtcAudioSession.lockForConfiguration()
//        do {
//            try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
//            try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
//        } catch {
//            logger.error("Error changeing AVAudioSession category: \(error)")
//        }
//        self.rtcAudioSession.unlockForConfiguration()
//        #endif
//    }
//    
//    private func createMediaSenders() {
//        let streamId = "stream"
//        
//        // Audio
//        let audioTrack = self.createAudioTrack()
//        self.peerConnection.add(audioTrack, streamIds: [streamId])
//        
//        // Data
//        if let dataChannel = createDataChannel() {
//            dataChannel.delegate = self
//            self.localDataChannel = dataChannel
//        }
//    }
//    
//    private func createAudioTrack() -> RTCAudioTrack {
//        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
//        let audioSource = WebRTCClient.factory.audioSource(with: audioConstraints)
//        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio0")
//        return audioTrack
//    }
//    
//    // MARK: Data Channels
//    private func createDataChannel() -> RTCDataChannel? {
//        let config = RTCDataChannelConfiguration()
//        guard let dataChannel = self.peerConnection.dataChannel(forLabel: "WebRTCData", configuration: config) else {
//            logger.error("Warning: Couldn't create data channel.")
//            return nil
//        }
//        return dataChannel
//    }
//    
//    func sendData(_ data: Data) {
//        let buffer = RTCDataBuffer(data: data, isBinary: true)
//        self.remoteDataChannel?.sendData(buffer)
//    }
//    
//    func readICECandidateQueue() {
//        for candidate in discoveredICECandidateQueue {
//            self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
//        }
//        
//        discoveredICECandidateQueue.removeAll()
//    }
//}
//
//extension WebRTCClient: RTCPeerConnectionDelegate {
//    
//    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
//        switch stateChanged {
//        case .stable:
//            logger.debug("RTC Client state is stable")
//        case .haveLocalOffer:
//            logger.debug("RTC Client state is haveLocalOffer")
//        case .haveLocalPrAnswer:
//            logger.debug("RTC Client state is haveLocalPrAnswer")
//        case .haveRemoteOffer:
//            logger.debug("RTC Client state is haveRemoteOffer")
//        case .haveRemotePrAnswer:
//            logger.debug("RTC Client state is haveRemotePrAnswer")
//        case .closed:
//            logger.debug("RTC Client state is closed")
//        @unknown default:
//            logger.debug("RTC Client state is unknown")
//        }
//    }
//    
//    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
//        self.delegate?.webRTCClientDidConnect(self)
//    }
//    
//    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
//        self.delegate?.webRTCClientDidDisconnect(self)
//    }
//    
//    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
//        logger.debug("peerConnection should negotiate")
//    }
//    
//    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
//        let state = { () -> String in
//            switch newState {
//            case .closed:
//                return "Closed"
//            case .disconnected:
//                return "Disconnected"
//            case .connected:
//                return "Connected"
//            case .new:
//                return "New"
//            case .failed:
//                return "Failed"
//            case .count:
//                return "Count"
//            case .checking:
//                return "Checking"
//            case .completed:
//                return "Completed"
//            @unknown default:
//                return "IDK"
//            }
//        }
//        logger.debug("WebRTC discovered changed state, \(state())")
//            
//        self.delegate?.webRTCClient(self, didChangeConnectionState: newState)
//    }
//    
//    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
//        logger.debug("peerConnection new gathering state: \(newState)")
//    }
//    
//    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
//        if let delegate = delegate, delegate.canAcceptIceCandidates {
//            delegate.webRTCClient(self, didDiscoverLocalCandidate: candidate)
//        } else {
//            self.discoveredICECandidateQueue.append(candidate)
//        }
//    }
//    
//    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
//        logger.debug("peerConnection did remove candidate(s)")
//    }
//    
//    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
//        logger.debug("peerConnection did open data channel")
//        self.remoteDataChannel = dataChannel
//    }
//}
//extension WebRTCClient {
//    private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
//        peerConnection.transceivers
//            .compactMap { return $0.sender.track as? T }
//            .forEach { $0.isEnabled = isEnabled }
//    }
//}
//
//// MARK:- Audio control
//extension WebRTCClient {
//    func muteAudio() {
//        self.setAudioEnabled(false)
//    }
//    
//    func unmuteAudio() {
//        self.setAudioEnabled(true)
//    }
//    
//    // Fallback to the default playing device: headphones/bluetooth/ear speaker
//    func speakerOff() {
//        #if os(iOS)
//        self.audioQueue.async { [weak self] in
//            guard let self = self else {
//                return
//            }
//            
//            self.rtcAudioSession.lockForConfiguration()
//            do {
//                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
//                try self.rtcAudioSession.overrideOutputAudioPort(.none)
//            } catch let error {
//                logger.debug("Error setting AVAudioSession category: \(error)")
//            }
//            self.rtcAudioSession.unlockForConfiguration()
//        }
//        #endif
//    }
//    
//    // Force speaker
//    func speakerOn() {
//        #if os(iOS)
//        self.audioQueue.async { [weak self] in
//            guard let self = self else {
//                return
//            }
//            
//            self.rtcAudioSession.lockForConfiguration()
//            do {
//                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
//                try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
//                try self.rtcAudioSession.setActive(true)
//            } catch let error {
//                logger.debug("Couldn't force audio to speaker: \(error)")
//            }
//            self.rtcAudioSession.unlockForConfiguration()
//        }
//        #endif
//    }
//    
//    private func setAudioEnabled(_ isEnabled: Bool) {
//        self.audioQueue.async {
//            self.setTrackEnabled(RTCAudioTrack.self, isEnabled: isEnabled)
//        }
//    }
//}
//
//extension WebRTCClient: RTCDataChannelDelegate {
//    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
//        logger.debug("dataChannel did change state: \(dataChannel.readyState)")
//    }
//    
//    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
//        self.delegate?.webRTCClient(self, didReceiveData: buffer.data)
//    }
//}
