//
//  CustomActionSheetPresenter.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 16/04/2021.
//

import SwiftUI
import Router
import SwiftUIX

struct CustomActionSheetPresenter: Presenter {
    let presentationMode = RoutePresentationMode.sibling
    
    func body(with context: PresentationContext) -> some View {
        CustomActionSheet(
            contents: context.destination,
            isPresented: context.$isPresented
        )
    }
}

private struct CustomActionSheet<V: View>: View {
    let contents: V
    @Binding var isPresented: Bool
    @ObservedObject var keyboard = Keyboard.main
    @State var appeared = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(appeared ? 0.7 : 0)
                .zIndex(2)
                .animation(.easeInOut(duration: keyboard.state.animationDuration))
                .onTapGesture {
                    appeared = false
                    keyboard.dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                        isPresented = false
                    }
                }
            
            if appeared {
                contents.background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(radius: 25)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, UIApplication.shared.windows[0].safeAreaInsets.bottom)
                .padding(.bottom, keyboard.state.height ?? 0)
                .zIndex(3)
                .animation(.easeInOut(duration: keyboard.state.animationDuration))
                .transition(.move(edge: .bottom))
            }
        }.edgesIgnoringSafeArea(.all).onAppear {
            appeared = true
        }
    }
}
