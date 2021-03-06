//
//  CameraView.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 11/04/2021.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImagePicker: UIViewControllerRepresentable {
    let source: UIImagePickerController.SourceType
    let onSelect: (UIImage?) -> ()
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onSelect: (UIImage?) -> ()
        
        init(onSelect: @escaping (UIImage?) -> ()) {
            self.onSelect = onSelect
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onSelect(nil)
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            onSelect(info[.originalImage] as? UIImage)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let uiViewController = UIImagePickerController()
        uiViewController.sourceType = source
        if source == .camera {
            uiViewController.cameraCaptureMode = .photo
        }
        uiViewController.delegate = context.coordinator
        uiViewController.mediaTypes = [UTType.image.identifier]
        return uiViewController
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
