import PhotosUI
import SwiftUI

/// A transparent overlay view that presents the iOS 16+ PhotosPicker
/// when `isPresented` is true. Falls back gracefully — iOS 15 callers
/// should never instantiate this view.
@available(iOS 16.0, *)
struct PhotosPickerSheet: View {
    @Binding var isPresented: Bool
    let onPicked: (UIImage) -> Void
    let onCancelled: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var didCompletePick = false

    var body: some View {
        Color.clear
            .photosPicker(isPresented: $isPresented, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { newItem in
                guard let newItem else { return }
                didCompletePick = true
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onPicked(image)
                    } else {
                        onCancelled()
                    }
                    selectedItem = nil
                }
            }
            .onChange(of: isPresented) { presented in
                if !presented {
                    if didCompletePick {
                        didCompletePick = false
                    } else {
                        onCancelled()
                    }
                }
            }
    }
}
