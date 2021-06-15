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

#if canImport(UIKit)
import UIKit

extension UIImage {
    func resize(toTargetSize targetSize: CGSize) -> UIImage? {
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(origin: .zero, size: newSize)

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
#endif

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
                                guard let resized = image.resize(toTargetSize: .init(width: 500, height: 500)) else { return }
                                guard let jpeg = resized.jpegData(compressionQuality: 0.7) else { return }
                                
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
