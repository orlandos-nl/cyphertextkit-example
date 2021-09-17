//import Logging
//import WebRTC
//import CypherMessaging
//
//enum CallError: Error {
//    case invalidTransition, callDisconnected
//}
//
//public final class CallHandle: Equatable {
//    var sdp: String?
//    let contactUsername: Username
//    var callStart: Date?
//    
//    init(sdp: String? = nil, contactUsername: Username) {
//        self.sdp = sdp
//        self.contactUsername = contactUsername
//    }
//    
//    public static func ==(lhs: CallHandle, rhs: CallHandle) -> Bool {
//        lhs.contactUsername == rhs.contactUsername
//    }
//}
//
//final actor Call<Chat: AnyConversation> {
//    let chat: Chat
//    private(set) var rtc: WebRTCClient?
//    var sessionEnded: Bool { rtc == nil }
//    let callStart: Date?
//    var callState: CallState<CallHandle>
//    let logger: Logger
//    
//    init(chat: Chat, rtc: WebRTCClient) {
//        self.chat = chat
//        self.logger = rtc.logger
//        self.rtc = rtc
//    }
//    
//    private func hangupCall(_ call: CallHandle) async throws {
//        try await chat.sendRawMessage(
//            type: .magic,
//            messageSubtype: "call/end",
//            text: "",
//            preferredPushType: .none
//        )
//        
//        if let callStart = callStart {
//            try await chat.saveLocalMessage(
//                type: .media,
//                messageSubtype: "call/success",
//                text: "",
//                metadata: [
//                    "duration": callStart.timeIntervalSinceNow
//                ]
//            )
//        } else {
//            try await chat.saveLocalMessage(
//                type: .media,
//                messageSubtype: "call/missed",
//                text: ""
//            )
//        }
//    }
//    
//    private func acceptCall(_ call: CallHandle) async throws {
//        guard let rtc = rtc else {
//            throw CallError.callDisconnected
//        }
//        
//        guard let sdp = call.sdp else {
//            logger.debug("Other user's SDP is unknown")
//            // Other user MUST send an SDP
//            throw CallError.invalidTransition
//        }
//        
//        logger.debug("Accept call - Sending SDP - \(sdp)")
//        do {
//            try await rtc.set(
//                remoteSdp: RTCSessionDescription(
//                    type: .offer,
//                    sdp: sdp
//                )
//            )
//            
//            let session = try await rtc.answer()
//            try await self.chat.sendRawMessage(
//                type: .magic,
//                messageSubtype: "call/answer",
//                text: session.sdp,
//                preferredPushType: .none
//            )
//        } catch {
//            self.logger.debug("Error setting offer \(error)")
//            try await self.callAction(.currentUser(to: call, .endCall))
//        }
//    }
//    
//    func callAction(_ action: UserCallAction<CallHandle>) async throws {
//        guard let rtc = rtc else {
//            throw CallError.callDisconnected
//        }
//        
//        switch callState.executeAction(action) {
//        case .none:
//            ()
//        case .prepareCall:
//            rtc.readICECandidateQueue()
//            // Prepare default sound state
//            rtc.speakerOff()
//            rtc.unmuteAudio()
//        case let .some(.acceptCall(with: call)):
//            try await acceptCall(call)
//        case let .some(.startCall(with: call)):
//            let sdp = try await rtc.offer()
//            try await self.chat.sendRawMessage(
//                type: .magic,
//                messageSubtype: "call/request",
//                text: sdp,
//                preferredPushType: .call
//            )
//        case let .some(.endCall(with: call)):
//            try await hangupCall(call)
//            
//            if case .idle = callState {
//                self.rtc = nil
//            }
//        case let .some(.tooManyCallers(to: call)):
//            try await chat.sendRawMessage(
//                type: .magic,
//                messageSubtype: "call/busy",
//                text: "",
//                preferredPushType: .none
//            )
//        case let .some(.tuple(hangUp: hangUpCall, accept: acceptCall)):
//            try await self.hangupCall(hangUpCall)
//            try await self.acceptCall(acceptCall)
//        }
//        
//#if canImport(UIKit)
//        if case .idle = callState {
//            UIApplication.shared.isIdleTimerDisabled = false
//            UIDevice.current.isProximityMonitoringEnabled = false
//        } else {
//            UIApplication.shared.isIdleTimerDisabled = true
//            UIDevice.current.isProximityMonitoringEnabled = true
//        }
//#endif
//    }
//    
//func startCall(withUsername username: Username) {
//    main {
//        do {
//            try self.callAction(.currentUser(to: Call(contactUsername: username), .startCall))
//        } catch {}
//    }
//    
//    self.hangupDate = Date().addingTimeInterval(Constants.maxRingTime - 5)
//    
//    // Hang up after 55 seconds of no answer
//    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(Constants.maxRingTime))) {
//        // Check the calldate again, this might be a second call which was invoked
//        // So we shouldn't blindly kill the call
//        if let hangupDate = self.hangupDate, hangupDate <= Date() {
//            switch self.callState {
//            case let .active(.calling(call)):
//                try? self.callAction(.currentUser(to: call, .endCall))
//            case let .activeAndIncoming(.calling(call), _):
//                try? self.callAction(.currentUser(to: call, .endCall))
//            default:
//                ()
//            }
//        }
//    }
//}
//    
//func signalIncomingCall(_ call: CallHandle) async throws {
//    try await self.callAction(.otherUser(from: call, .startCall))
//}
//    
//func receivedEndCall(sender username: Username) async throws {
//    switch self.callState {
//    case .active(.beingCalled(by: let handle)) where handle.contactUsername == username:
//        switch handle.callStart {
//        case .some(let date) where abs(date.timeIntervalSinceNow) <= 2:
//            fallthrough
//        case .none:
//            // App was not properly started / the call was hung up quickly
//            self.missedCall = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
//                self.missedCall = false
//            }
//        case .some:
//            ()
//        }
//        
//        try? self.callAction(.otherUser(from: handle, .endCall))
//    case .active(let activeCall):
//        try? self.callAction(.otherUser(from: activeCall.handle, .endCall))
//    case .activeAndIncoming(let activeCall, _) where activeCall.handle.contactUsername == username:
//        try? self.callAction(.otherUser(from: activeCall.handle, .endCall))
//    case .activeAndIncoming(_, let newCall) where newCall.contactUsername == username:
//        try? self.callAction(.otherUser(from: newCall, .endCall))
//    default:
//        ()
//    }
//}
//    
//func receivedIceCandidates(_ candidate: IceCandidate, sender: Username) {
//    logger.debug("Processing ICE candidate", candidate)
//    
//    withRTC { rtc in
//        guard
//            case .active(let activeState) = self.callState,
//            activeState.handle.contactUsername == sender
//        else {
//            logger.debug("ICE candidate invalid")
//            return
//        }
//        
//        rtc.set(remoteCandidate: candidate.rtcIceCandidate)
//    }
//}
//    
//func signalReceiveAnswerCall(_ sdp: String, sender: Username) {
//    let call: Call
//    
//    switch callState {
//    case .active(let activeState):
//        guard activeState.handle.contactUsername == sender else {
//            return
//        }
//        
//        call = activeState.handle
//    case .activeAndIncoming(let activeState, let secondCall):
//        if activeState.handle.contactUsername == sender {
//            call = activeState.handle
//        } else if secondCall.contactUsername == sender {
//            call = secondCall
//        } else {
//            return
//        }
//    case .idle:
//        return
//    }
//    
//    call.sdp = sdp
//    
//    withRTC { rtc in
//        rtc.set(remoteSdp: RTCSessionDescription(type: .answer, sdp: sdp)) { error in
//            main {
//                if error != nil {
//                    try? self.callAction(.currentUser(to: call, .endCall))
//                } else {
//                    try? self.callAction(.otherUser(from: call, .startCall))
//                }
//            }
//        }
//    }
//}
//    
//func signalAcceptCall(sdp: String, username: Username, completion: @escaping (Error?) -> ()) {
//    withRTC { rtc in
//        rtc.set(remoteSdp: RTCSessionDescription(type: .offer, sdp: sdp)) { error in
//            rtc.answer { session in
//                self.makeRepositories().chats.sendPrivateMessage(
//                    SpokeChatMessage(
//                        text: "",
//                        timeout: 60,
//                        attachment: .init(
//                            type: .answerCall,
//                            data: session.sdp.data(using: .utf8) ?? Data()
//                        ),
//                        pushType: .none,
//                        groupChatId: nil
//                    ),
//                    toUser: username
//                )
//                
//                rtc.readICECandidateQueue()
//                rtc.speakerOff()
//                rtc.unmuteAudio()
//                DispatchQueue.main.async {
//                    completion(nil)
//                }
//            }
//        }
//    }
//}
//}
//
//extension AuthenticatedAppState: WebRTCClientDelegate {
//func webRTCClientDidDisconnect(_ client: WebRTCClient) { }
//    
//func withRTC(perform: @escaping (WebRTCClient) -> ()) {
//    if let rtc = rtc {
//        perform(rtc)
//    } else {
//        self.client.requestRTCCredentials().whenSuccess { (username, password) in
//            let client = WebRTCClient(
//                iceServers: Constants.iceServers,
//                username: username,
//                password: password
//            )
//            client.delegate = self
//            DispatchQueue.main.async {
//                self.interrupted = false
//            }
//            self.rtc = client
//            perform(client)
//        }
//    }
//}
//    
//func webRTCClientDidConnect(_ client: WebRTCClient) {
//    debugLog(domain: .webrtc, "WebRTC connected")
//}
//    
//    var canAcceptIceCandidates: Bool {
//        switch callState {
//        case .active(.inCall), .activeAndIncoming(.inCall, _):
//            return true
//        case .active, .activeAndIncoming, .idle:
//            return false
//        }
//    }
//    
//func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
//    debugLog(domain: .webrtc, "WebRTC discovered a candidate")
//    
//    StaticAppState.eventLoop.execute {
//        let call: Call
//        switch self.callState {
//        case let .active(.calling(activeCall)):
//            call = activeCall
//        case let .active(.inCall(activeCall)):
//            call = activeCall
//        case let .activeAndIncoming(.inCall(activeCall), _):
//            call = activeCall
//        default:
//            debugLog(domain: .webrtc, "Cannot send ICE canidates yet")
//            return
//        }
//        
//        do {
//            let candidate = IceCandidate(from: candidate)
//            let bson = try BSONEncoder().encode(candidate)
//            debugLog(domain: .webrtc, "Sending ICE candidate", candidate)
//            self.makeRepositories().chats.sendPrivateMessage(
//                SpokeChatMessage(
//                    text: "",
//                    timeout: 60,
//                    attachment: .init(
//                        type: .callIceCandidates,
//                        data: bson.makeData()
//                    ),
//                    pushType: .none,
//                    groupChatId: nil
//                ),
//                toUser: call.contactUsername
//            )
//        } catch {}
//    }
//}
//    
//    /// - See: https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/iceConnectionState#RTCIceConnectionState_enum
//func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
//    DispatchQueue.main.async {
//        switch state {
//        case .closed:
//            self.success = false
//        case .disconnected:
//            self.interrupted = true
//        case .connected, .completed:
//            DispatchQueue.main.async {
//                switch self.callState {
//                case let .active(.calling(call)) where call.callStart == nil:
//                    call.callStart = Date()
//                case let .active(.beingCalled(by: call)) where call.callStart == nil:
//                    call.callStart = Date()
//                case let .active(.inCall(call)) where call.callStart == nil:
//                    call.callStart = Date()
//                case let .activeAndIncoming(.inCall(call), _) where call.callStart == nil:
//                    call.callStart = Date()
//                default:
//                    ()
//                }
//                
//                self.success = true
//                self.interrupted = false
//                self.missedCall = false
//            }
//        case .new, .count, .checking, .failed:
//            ()
//        @unknown default:
//            ()
//        }
//    }
//}
//    
//func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) { }
//}
