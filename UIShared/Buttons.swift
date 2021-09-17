//
//  Buttons.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 21/06/2021.
//

import SwiftUI

struct IconLabelButton: View {
    let label: Text
    let icon: Image
    let action: () -> ()
    
    var body: some View {
        HStack {
            label
            icon
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Capsule().fill(Color.white))
        .onTapGesture(perform: action)
    }
}

struct IconButton: View {
    let icon: Image
    
    var body: some View {
        icon
            .background(Circle().fill(Color.white))
            .frame(width: 44, height: 44)
    }
}
