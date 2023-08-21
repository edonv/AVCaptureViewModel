//
//  AVCaptureViewModel+PinchAndZoom.swift
//  
//
//  Created by Edon Valdman on 8/20/23.
//

import SwiftUI
import AVFoundation

extension AVCaptureViewModel {
    /// A [`MagnificationGesture`](https://developer.apple.com/documentation/swiftui/magnificationgesture) ready to plug into a [`.gesture(_:including:)`](https://developer.apple.com/documentation/swiftui/view/gesture(_:including:)) view modifier.
    ///
    /// Internally, it calls ``zoom(_:)``.
    public var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged(zoom(_:))
    }
    
    /// Zooms the camera.
    ///
    /// To use this functionality, attach it directly to ``CameraPreview`` with a [`MagnificationGesture`](https://developer.apple.com/documentation/swiftui/magnificationgesture) and [`onChanged(_:)`](https://developer.apple.com/documentation/swiftui/magnificationgesture/onchanged(_:)) using [`.gesture(_:including:)`](https://developer.apple.com/documentation/swiftui/view/gesture(_:including:)):
    /// ```swift
    /// struct ContentView: View {
    ///     var body: some View {
    ///         CameraPreview(...)
    ///             .gesture(MagnificationGesture()
    ///                 .onChanged(zoom(_:))
    ///     }
    /// }
    /// ```
    /// - Parameter scale: The scale factor of the zoom.
    public func zoom(_ scale: CGFloat) {
        // Limit the factor to be at least 1
        let device = self.videoDeviceInput.device
        let factor = min(max(scale, 1), device.activeFormat.videoMaxZoomFactor)
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = factor
            device.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
}
