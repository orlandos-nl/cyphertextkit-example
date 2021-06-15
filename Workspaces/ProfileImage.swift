//
//  ProfileImage.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 14/06/2021.
//

import SwiftUI

struct ProfileImage: View {
    let data: Data?
    
    @ViewBuilder var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .strokeBorder(Color.gray, lineWidth: 2)
                .overlay(
                    Image(systemName: "person")
                        .scaledToFit()
                        .foregroundColor(.gray)
                        .padding(8)
                )
        }
    }
}
