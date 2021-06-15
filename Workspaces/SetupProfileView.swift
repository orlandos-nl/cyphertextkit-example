//
//  SetupProfileView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Spacer()
            
            configuration.label
            
            Spacer()
        }
        .font(.system(size: 16, weight: .medium))
        .frame(height: 44)
        .background(Capsule().fill(configuration.isPressed ? Color(white: 0.9) : Color.white))
    }
}

struct SetupProfileView: View {
    @State var showImagePicker: UIImagePickerController.SourceType?
    @State var image: UIImage?
    
    var body: some View {
        ZStack {
            Color.blue
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                ProfileImageView(image: image.map(Image.init(uiImage:))).onTapGesture {
                    showImagePicker = .camera
                }.padding(.vertical, 44)
                
                Button("Change Profile Picture") {
                    showImagePicker = .camera
                }.buttonStyle(ActionButtonStyle())
                .padding(.horizontal, 44)
                
                Spacer()
            }
            
            if let showImagePicker = showImagePicker {
                ImagePicker(source: showImagePicker) { image in
                    if let image = image {
                        self.image = image
                    }
                    
                    self.showImagePicker = nil
                }
                .edgesIgnoringSafeArea(.all)
                .zIndex(2)
                .transition(AnyTransition.opacity)
            }
        }
    }
}

struct ProfileImageView: View {
    let image: Image?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .shadow(radius: 15)
                    .frame(width: 150, height: 150)
            } else {
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 15)
                
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color(white: 0.3))
                    .padding(44)
            }
                
            ZStack {
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 5)
                
                Image(systemName: "camera")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color(white: 0.3))
                    .padding(12)
            }.frame(width: 44, height: 44)
        }.frame(width: 150, height: 150)
    }
}

struct SetupProfileView_Previews: PreviewProvider {
    static var previews: some View {
        SetupProfileView()
    }
}
