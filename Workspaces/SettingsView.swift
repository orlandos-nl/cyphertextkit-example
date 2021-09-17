//
//  SettingsView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import CypherMessaging
import MessagingHelpers
import SwiftUI
import Logging

struct SettingsView: View {
    @Environment(\.messenger) var messenger
    @State var metadata: ContactMetadata
    @State var destroying = false
    
    var body: some View {
        Form {
            Section(header: Text("My Profile")) {
                NavigationLink(
                    destination: EditProfileView(
                        metadata: $metadata,
                        status: metadata.status ?? "Available"
                    )
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
                        }.frame(height: 44)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .background(Color(white: 0, opacity: 0.001))
                }
            }
            
            Section(header: Text("Devices")) {
                NavigationLink(
                    "Add Device",
                    destination: AddDeviceView()
                )
            }
        }.navigationTitle("Settings")
    }
}

struct AddDeviceView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.messenger) var messenger
    @State var config: UserDeviceConfig?
    
    var body: some View {
        if let config = config {
            Form {
                Text("Do you want to register this device?")
                
                Button("Add Device") {
                    Task.detached {
                        try await messenger.addDevice(config)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.foregroundColor(.red)
            }
        } else {
            CodeScannerView(codeTypes: [.qr]) { result in
                switch result {
                case .success(let code):
                    guard let data = Data(base64Encoded: code) else {
                        return
                    }
                    
                    do {
                        self.config = try BSONDecoder().decode(
                            UserDeviceConfig.self,
                            from: Document(data: data)
                        )
                    } catch {}
                case .failure:
                    ()
                }
            }
        }
    }
}
