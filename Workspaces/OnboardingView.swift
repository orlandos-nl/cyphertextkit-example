import CypherMessaging
import AuthenticationServices
import SwiftUI
import MessagingHelpers

enum OnboardingMode {
    case onboarding
    case setup(username: String, appleToken: String?)
    case done(CypherMessenger, SwiftUIEventEmitter)
}

struct OnboardingView: View {
    @State var tabItem = 0
    @Binding var onboardingMode: OnboardingMode
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue,
                    Color.blue,
                    Color.purple
                ]),
                startPoint: .top,
                endPoint: .bottom
            ).edgesIgnoringSafeArea(.all)
            
            TabView(selection: $tabItem) {
                View1().tag(0)
                View2().tag(1)
                View3(onboardingMode: $onboardingMode).tag(2)
            }.tabViewStyle(PageTabViewStyle())
            
            if tabItem != 2 {
                Button(action: {
                    withAnimation {
                        tabItem = 2
                    }
                }) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .light))
                        .frame(height: 52)
                        .padding(.horizontal, 24)
                        .foregroundColor(.white)
                }
                .zIndex(2) // Used to fix the transition
                .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
    }
}

private struct View1: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Workspaces")
                .font(.largeTitle)
                .fontWeight(.medium)
            
            Text("Secure Communication made Easy.")
            
            Spacer()
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(44)
        .padding(.bottom, 22)
    }
}

private struct View2: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Blabla")
                .font(.largeTitle)
                .fontWeight(.medium)
            
            Text("BlablaBlablaBlabla")
            
            Spacer()
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(44)
        .padding(.bottom, 22)
    }
}

private struct View3: View {
    @Binding var onboardingMode: OnboardingMode
    @State var failed = false
    @State var username = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Connect to Work")
                .font(.largeTitle)
                .fontWeight(.medium)
            
            Text("Start chatting with colleagues!")
                .foregroundColor(.white)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .foregroundColor(.black)
            
            Spacer()
            
            VStack {
                if failed {
                    Text("Failed to register Apple ID")
                        .font(.system(size: 14))
                        .zIndex(2)
                        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
                }
                
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { _ in }, // Ask for no metadata
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                                return
                            }
                            
                            guard let tokenData = credential.identityToken, let appleToken = String(data: tokenData, encoding: .utf8) else {
                                return
                            }
                            
                            self.onboardingMode = .setup(username: username, appleToken: appleToken)
                            self.failed = false
                        case .failure:
                            self.failed = true
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .disabled(username.isEmpty)
                .frame(height: 44)
                
                Button("Sign Up Regularly") {
                    let username = self.username.replacingOccurrences(of: "@", with: "")
                    self.onboardingMode = .setup(username: username, appleToken: .none)
                }.disabled(username.isEmpty)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(44)
        .padding(.bottom, 22)
    }
}
