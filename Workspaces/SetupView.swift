//
//  SetupView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import CypherMessaging
import MessagingHelpers

struct SetupView: View {
    @State var onboardingMode = OnboardingMode.onboarding
    
    @ViewBuilder var body: some View {
        ZStack {
            switch onboardingMode {
            case .onboarding:
                OnboardingView(onboardingMode: $onboardingMode)
                    .transition(
                        AnyTransition.asymmetric(
                            insertion: .identity,
                            removal: AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.3).delay(0.3))
                        )
                    )
                    .zIndex(3)
            case .setup(let username, let appleToken):
                ProcessingView(
                    username: username,
                    appleToken: appleToken,
                    onboardingMode: $onboardingMode
                ).transition(
                    AnyTransition.asymmetric(
                        insertion: AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.1)),
                        removal: AnyTransition.move(edge: .leading)
                            .animation(Animation.easeInOut(duration: 0.3))
                    )
                ).zIndex(2)
            case .done(let messenger, let emitter):
                AppView()
                    .edgesIgnoringSafeArea(.all)
                    .transition(
                        AnyTransition.asymmetric(
                            insertion: AnyTransition.move(edge: .trailing)
                                .animation(Animation.easeInOut(duration: 0.3)),
                            removal: AnyTransition.identity
                        )
                    )
                    .environment(\.messenger, messenger)
                    .environment(\.plugin, emitter)
            }
        }
    }
}

struct ProcessingView: View {
    let username: String
    let appleToken: String?
    @Binding var onboardingMode: OnboardingMode
    @State var progress: CGFloat = 0
    @State var error = false
    @State var task = "Generating Keys"
    @State var taskDescription = "This ensures secure communication."
    @State var success: (CypherMessenger, SwiftUIEventEmitter)?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                gradient: Gradient(colors: [
                    error ? .red : .blue,
                    error ? .red : .blue,
                    .purple
                ]),
                startPoint: .top,
                endPoint: .init(x: 0.5, y: max(1 - progress, 0.0001))
            ).edgesIgnoringSafeArea(.all).onAppear {
                asyncDetached {
                    do {
                        let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
                        let emitter = makeEventEmitter()
                        let store = try await SQLiteStore.create(on: eventLoop)
                        let messenger = try await CypherMessenger.registerMessenger(
                            username: Username(username),
                            appPassword: "",
                            usingTransport: { request async throws -> VaporTransport in
                                DispatchQueue.main.async {
                                    self.task = "Registering Device"
                                    taskDescription = "We're almost ready!"
                                    self.advance(to: 0.6)
                                }
                                
                                if let appleToken = appleToken {
                                    return try await VaporTransport.register(
                                        appleToken: appleToken,
                                        transportRequest: request,
                                        host: Constants.host,
                                        eventLoop: eventLoop
                                    )
                                } else {
                                    return try await VaporTransport.registerPlain(
                                        transportRequest: request,
                                        host: Constants.host,
                                        eventLoop: eventLoop
                                    )
                                }
                            },
                            p2pFactories: makeP2PFactories(),
                            database: store,
                            eventHandler: makeEventHandler(emitter: emitter),
                            on: eventLoop
                        )
                        
                        await emitter.boot(for: messenger)
                        
                        self.complete(messenger: messenger, emitter: emitter)
                    } catch {
                        self.fail(error: error)
                        SQLiteStore.destroy()
                    }
                }
                
                func next() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                        advance(to: self.progress + 0.3)
                        next()
                    }
                }
                
                next()
            }
            
            VStack {
                Spacer()
                
                if success == nil && !error {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(3)
                        .padding(.bottom, 44)
                }
                
                Text(task)
                    .font(.title)
                    .animation(.easeInOut(duration: 0.3))
                
                Text(taskDescription)
                    .font(.system(size: 14))
                    .animation(.easeInOut(duration: 0.3))
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)

            if let success = success {
                IconLabelButton(
                    label: Text("Continue"),
                    icon: Image(systemName: "arrow.right")
                ) {
                    onboardingMode = .done(success.0, success.1)
                }
                .padding(44)
                .zIndex(3)
                .transition(
                    AnyTransition.asymmetric(insertion: .move(edge: .trailing), removal: .identity)
                )
            }
        }
        .zIndex(2)
        .transition(
            AnyTransition.asymmetric(
                insertion: AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.3)),
                removal: AnyTransition.move(edge: .leading).animation(.easeInOut(duration: 0.3))
            )
        )
        .edgesIgnoringSafeArea(.all)
    }
    
    @MainActor
    func advance(to progress: CGFloat) {
        if error { return }
        
        withAnimation(.easeInOut(duration: 0.7)) {
            self.progress = progress
        }
    }
    
    func fail(error: Error) {
        withAnimation(.easeInOut(duration: 0.7)) {
            self.progress = 0
            self.error = true
            self.task = "Setup Failed"
            self.taskDescription = "Please check your internet connection"
        }
    }
    
    func complete(messenger: CypherMessenger, emitter: SwiftUIEventEmitter) {
        if error { return }
        
        withAnimation(.easeInOut(duration: 0.7)) {
            self.progress = 1
            self.success = (messenger, emitter)
            self.task = "All Set Up!"
            self.taskDescription = "Continue to set up your account"
        }
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView()
    }
}
