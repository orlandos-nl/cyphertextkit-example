//
//  TabViewPresenter.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 18/04/2021.
//

import SwiftUI
import Router

struct BottomBarPresenter: Presenter {
    let item: BottomBar.Item
    let presentationMode = RoutePresentationMode.replaceParent

    func body(with context: PresentationContext) -> some View {
        VStack(spacing: 0) {
            context.destination

            Spacer(minLength: 0)
            
            Divider()

            BottomBar(selectedItem: item)
        }.edgesIgnoringSafeArea(.bottom)
    }
}

struct BottomBar: View {
    enum Item: CaseIterable {
        case contacts, chats, settings
        
        var title: String {
            switch self {
            case .contacts:
                return "Contacts"
            case .chats:
                return "Chats"
            case .settings:
                return "Settings"
            }
        }
        
        var selectedImage: Image {
            switch self {
            case .contacts:
                return Image(systemName: "person.3.fill")
            case .chats:
                return Image(systemName: "text.bubble.fill")
            case .settings:
                return Image(systemName: "gear")
            }
        }
        
        var deselectedImage: Image {
            switch self {
            case .contacts:
                return Image(systemName: "person.3")
            case .chats:
                return Image(systemName: "text.bubble")
            case .settings:
                return Image(systemName: "gear")
            }
        }
        
        func route(for router: Router) {
            switch self {
            case .contacts:
                router.replaceRoot(
                    with: Routes.contacts,
                    using: BottomBarPresenter(item: .contacts)
                )
            case .chats:
                router.replaceRoot(
                    with: Routes.chats,
                    using: BottomBarPresenter(item: .chats)
                )
            case .settings:
                router.replaceRoot(
                    with: Routes.settings,
                    using: BottomBarPresenter(item: .settings)
                )
            }
        }
    }
    
    @State var selectedItem: Item
    @Environment(\.router) var router
    
    func itemView(item: Item) -> some View {
        VStack(spacing: 4) {
            (selectedItem == item ? item.selectedImage : item.deselectedImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 44, maxHeight: 24)
            
            Text(item.title)
                .font(.system(size: 13, weight: selectedItem == item ? .medium : .regular))
        }
        .frame(minWidth: 44, minHeight: 44)
        .background(Color.white.opacity(0.0001))
        .foregroundColor(selectedItem == item ? .blue : .gray)
        .animation(.easeIn)
        .onTapGesture {
            selectedItem = item
            
            if let router = router {
                item.route(for: router)
            }
        }
    }
    
    var body: some View {
        HStack {
            itemView(item: .contacts)
            
            Spacer()
            
            itemView(item: .chats)
            
            Spacer()
            
            itemView(item: .settings)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 6)
        .padding(.bottom, UIApplication.shared.windows[0].safeAreaInsets.bottom)
        .background(Color(white: 0.98))
    }
}
