//
//  MessageCell.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 19/04/2021.
//

import SwiftUI
import CypherMessaging

struct MessageCell: View {
    @Environment(\.messenger) var messenger
    let message: AnyChatMessage
    
    var isWrittenByMe: Bool {
        message.raw.senderUser == messenger.username
    }
    
    @ViewBuilder var body: some View {
        switch message.raw.message.messageType {
        case .text:
            HStack {
                if isWrittenByMe {
                    Spacer(minLength: 100)
                }
                
                ZStack(alignment: .bottomTrailing) {
                    Text(message.raw.message.text)
                        .padding(.bottom, 14)
                        .frame(minWidth: 50, alignment: .topLeading)
                    
                    Text(date: message.raw.sendDate, requiresTime: true)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.gray)
                }
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isWrittenByMe ? Color(white: 0.97) : Color(white: 0.95)
                        )
                )
                .padding(.horizontal, 8)
                
                if !isWrittenByMe {
                    Spacer(minLength: 100)
                }
            }.onAppear {
                asyncDetached {
                    try await message.markAsRead()
                }
            }
        case .media:
            EmptyView()
        case .magic:
            EmptyView()
        }
    }
}
