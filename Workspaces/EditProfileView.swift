//
//  EditProfileView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 14/06/2021.
//

import SwiftUI
import MessagingHelpers
import Router

extension Routes {
    static func editProfile(_ metadata: Binding<ContactMetadata>) -> some Route {
        return SimpleRoute {
            EditProfileView(metadata: metadata, status: metadata.status.wrappedValue ?? "Available")
        }
    }
}

struct EditProfileView: View {
    @Environment(\.messenger) var messenger
    @Binding var metadata: ContactMetadata
    @State var status: String
    @State var selectPicture = false
    
    var body: some View {
        Form {
            Section(header: Text("Profile")) {
                HStack {
                    ProfileImage(data: metadata.image)
                        .overlay(Circle().foregroundColor(Color.black.opacity(0.7)))
                        .overlay(
                            Image(systemName: "camera")
                                .padding(8)
                                .foregroundColor(.white)
                        )
                        .frame(width: 64, height: 64)
                        .onTapGesture {
                            self.selectPicture = true
                        }.sheet(isPresented: $selectPicture) {
                            ImagePicker(source: .camera) { image in
                                selectPicture = false
                                
                                guard let image = image else { return }
                                guard let jpeg = image.jpegData(compressionQuality: 0.7) else { return }
                                
                                metadata.image = jpeg
                                
                                detach {
                                    try await messenger.changeProfilePicture(to: jpeg)
                                }
                            }.edgesIgnoringSafeArea(.all)
                        }
                    
                    VStack(alignment: .leading) {
                        Spacer()
                        
                        Text("@" + messenger.username.raw)
                            .bold()
                        
                        Divider()
                        
                        TextField(
                            "Status",
                            text: $status,
                            onCommit: {
                                detach {
                                    try await messenger.changeProfileStatus(to: metadata.status ?? "Available")
                                }
                                metadata.status = status
                            }
                        ).submitLabel(.done)
                        
                        Spacer()
                    }
                }
            }
        }
    }
}
