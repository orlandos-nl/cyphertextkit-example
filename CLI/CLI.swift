import MessagingHelpers
import CypherMessaging
import ConsoleKit

struct ConsolePlugin: Plugin {
    static let pluginIdentifier = "console"
    let console: Terminal
    
    func onCreateChatMessage(_ messsage: AnyChatMessage) {
        console.output("\(messsage.sender.raw): \(messsage.text)")
    }
}

@main
struct App {
    static func main() {
        let eventloop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
        _ = eventloop.executeAsync {
            let console = Terminal()
            let handler = PluginEventHandler(plugins: [
                FriendshipPlugin(ruleset: {
                    var ruleset = FriendshipRuleset()
                    ruleset.ignoreWhenUndecided = true
                    ruleset.preventSendingDisallowedMessages = true
                    return ruleset
                }()),
                UserProfilePlugin(),
                ChatActivityPlugin(),
                ConsolePlugin(console: console),
            ])
            let app: CypherMessenger
            
            if !SQLiteStore.exists() {
                console.output("To start chatting, first setup your client:\n")
                console.output("Your App Password is used to unlock the app")
                console.output("Enter App Password:".consoleText(isBold: true))
                let appPassword = console.input(isSecure: true)
                
                console.output("Create or Log Into Your Account")
                console.output("Username:".consoleText(isBold: true))
                let username = console.input(isSecure: false)
                
                app = try await .registerMessenger(
                    username: Username(username),
                    appPassword: appPassword,
                    usingTransport: { request in
                        try await VaporTransport.registerPlain(transportRequest: request, host: Constants.host, eventLoop: eventloop)
                    },
                    database: SQLiteStore.create(on: eventloop),
                    eventHandler: handler
                )
            } else {
                console.output("Enter App Password".consoleText(isBold: true))
                sleep(1)
                let appPassword = console.input(isSecure: true)
                
                app = try await .resumeMessenger(
                    appPassword: appPassword,
                    usingTransport: { request in
                        try await VaporTransport.login(for: request, host: Constants.host)
                    },
                    database: SQLiteStore.create(on: eventloop),
                    eventHandler: handler
                )
            }
            
            Task.detached {
                while true {
                    console.output("Recipient username:")
                    let username = Username(console.input())
                    let contact: Contact
                    if let _contact = try await app.getContact(byUsername: username) {
                        contact = _contact
                    } else {
                        contact = try await app.createContact(byUsername: username)
                    }
                    
                    if contact.ourState == .undecided {
                        try await contact.befriend()
                    }
                    
                    console.output("Message:")
                    let message = console.input(isSecure: false)
                    
                    let chat = try await app.createPrivateChat(with: username)
                    _ = try await chat.sendRawMessage(type: .text, text: message, preferredPushType: .message)
                }
            }
        }
        
        RunLoop.main.run()
    }
}
