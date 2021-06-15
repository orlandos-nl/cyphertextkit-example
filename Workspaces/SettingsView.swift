//
//  SettingsView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import MessagingHelpers
import SwiftUI
import Router
import Logging

extension Routes {
    static var settings: some Route {
        struct _SettingsViewWrapper: View {
            @Environment(\.messenger) var messenger
            
            var body: some View {
                AsyncView(run: {
                    try await messenger.readProfileMetadata()
                }) { metadata in
                    SettingsView(metadata: metadata)
                }
            }
        }
        
        return SimpleRoute {
            _SettingsViewWrapper()
        }
    }
}

struct SettingsView: View {
    @Environment(\.messenger) var messenger
    @State var metadata: ContactMetadata
    @State var destroying = false
    
    var body: some View {
        Form {
            RouterLink(
                to: Routes.editProfile($metadata)
            ) {
                HStack {
                    ProfileImage(data: metadata.image)
                        .frame(width: 44, height: 44)
                    
                    VStack(alignment: .leading) {
                        Text("@" + messenger.username.raw)
                            .font(.system(size: 16, weight: .medium))
                            .bold()
                        
                        Text(metadata.status ?? "Available")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.gray)
                    }.frame(height: 38)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }.navigationTitle("Settings")
    }
}
