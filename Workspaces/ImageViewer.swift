//
//  ImageViewer.swift
//  Spoke
//
//  Created by Joannis Orlandos on 13/10/2020.
//

import SwiftUI

struct ImageViewer: View {
    let image: Image
    @State var dragOffset = CGSize.zero
    @State var initialDragOffset: CGSize? = nil
    @State var zoomScale: CGFloat = 1
    @State var initialZoomScale: CGFloat? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Color.black
                
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoomScale)
                    .offset(x: dragOffset.width, y: dragOffset.height)
                    .gesture(MagnificationGesture().onChanged { value in
                        if initialZoomScale == nil {
                            initialZoomScale = zoomScale
                        }
                        
                        onScaleChange(value)
                    }.onEnded { value in
                        onScaleChange(value)
                        initialZoomScale = nil
                    }.simultaneously(with: DragGesture().onChanged { drag in
                        if initialDragOffset == nil {
                            initialDragOffset = dragOffset
                        }
                        
                        onPositionChange(drag.translation)
                    }.onEnded { drag in
                        onPositionChange(drag.translation)
                        initialDragOffset = nil
                    }))
            }.edgesIgnoringSafeArea(.all)
            
            Image(systemName: "xmark")
                .resizable()
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .padding(12)
                .background(Color(white: 0, opacity: 0.001))
                .onTapGesture {
                    presentationMode.wrappedValue.dismiss()
                }
        }
        .statusBar(hidden: true)
        .navigationBarHidden(true)
    }
    
    func onScaleChange(_ newScale: CGFloat) {
        let minScale: CGFloat = 1
        let maxScale: CGFloat = 5
        let raw = newScale * (initialZoomScale ?? maxScale)
        self.zoomScale = max(minScale, min(maxScale, raw))
        
        if zoomScale <= 1.2 {
            zoomScale = 1
        }
        
        // Correct the offset, because zoom may mess with it
        self.onPositionChange(dragOffset)
    }
    
    func onPositionChange(_ newOffset: CGSize) {
        var size = initialDragOffset ?? .zero
        
        size.width += newOffset.width
//        size.height += newOffset.height
        
        let imageWidth = UIScreen.main.bounds.width * zoomScale
//        let imageHeight = UIScreen.main.bounds.height * zoomScale
        
        let overflowWidth = abs(imageWidth - UIScreen.main.bounds.width)
//        let overflowHeight = abs(imageHeight - UIScreen.main.bounds.height)
        
        let maxOverflowX = overflowWidth / 2
//        let maxOverflowY = overflowHeight / 2
        
        // If the screen is 300px wide, and the image size is 300px but zoomed in at 2x (so 600px)
        // maxOverflowX is then 150px (300px difference / 2)
        if size.width > maxOverflowX {
            // If the screen is further than the 150px of left-sideoverflow scrolled into negative on the X axis, this shows black on the right
            size.width = maxOverflowX
        } else if size.width < -maxOverflowX {
            // If the screen is further than 300px to the right, likewise as the above
            // However, the boundary is opposite, and we render from left
            // If the offset is -160 (10 too much) we'll need to reset to -150
            // 160px (offset) + 300 (visible screen width) makes for 10 pixels not being shown on that side
            size.width = -maxOverflowX
        }
        
        dragOffset = size
    }
}
