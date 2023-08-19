//
//  AVCaptureViewModel+TapAndFocus.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import SwiftUI
import AVFoundation

extension AVCaptureViewModel {
    /// Focuses and exposes the camera from a SwiftUI tap on a ``CameraPreview``.
    ///
    /// - Note: This function autofocuses ([`.autoFocus`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/focusmode/autofocus)) and uses auto-exposure ([`.autoExpose`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposuremode/autoexpose)). If you'd like to pass custom parameters, use ``focus(with:exposureMode:at:)``.
    ///
    /// - Important: This function is for SwiftUI. For UIKit, see ``focusAndExposeTap(gestureRecognizer:)`` and ``focus(with:exposureMode:gestureRecognizer:)``.
    ///
    /// - Important: Taps are cut off if they're outside the actual preview area. If there is blank space around the preview, it will still register taps, but those calls will be cut off before focusing actually takes place.
    ///
    /// To use this functionality, attach it directly to ``CameraPreview`` with [`onTapGesture(count:coordinateSpace:perform:)`](https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:coordinatespace:perform:)):
    /// ```swift
    /// struct ContentView: View {
    ///     var body: some View {
    ///         CameraPreview(...)
    ///             .onTapGesture(perform: viewModel.focusAndExposeTap(at:))
    ///     }
    /// }
    /// ```
    public func focusAndExposeTap(at touchPosition: CGPoint) {
        focus(with: .autoFocus, exposureMode: .autoExpose, at: touchPosition)
    }
    
    /// Focuses and exposes the camera from a SwiftUI tap on a ``CameraPreview``.
    ///
    /// - Note: If you'd like to use plain autofocus ([`.autoFocus`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/focusmode/autofocus)) and auto-exposure ([`.autoExpose`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposuremode/autoexpose)), use ``focusAndExposeTap(at:)``.
    ///
    /// - Important: This function is for SwiftUI. For UIKit, see ``focusAndExposeTap(gestureRecognizer:)`` and ``focus(with:exposureMode:gestureRecognizer:)``.
    ///
    /// - Important: Taps are cut off if they're outside the actual preview area. If there is blank space around the preview, it will still register taps, but those calls will be cut off before focusing actually takes place.
    ///
    /// To use this functionality, attach it directly to ``CameraPreview`` with [`onTapGesture(count:coordinateSpace:perform:)`](https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:coordinatespace:perform:)):
    /// ```swift
    /// struct ContentView: View {
    ///     var body: some View {
    ///         CameraPreview(...)
    ///             .onTapGesture(perform: viewModel.focusAndExposeTap(at:))
    ///     }
    /// }
    /// ```
    public func focus(with focusMode: AVCaptureDevice.FocusMode,
                      exposureMode: AVCaptureDevice.ExposureMode,
                      at touchPosition: CGPoint) {
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPosition)
        focus(with: focusMode, exposureMode: exposureMode, at: devicePoint, monitorSubjectAreaChange: true)
    }
    
    /// Focuses and exposes the camera from a UIKit `UITapGestureRecognizer` tap.
    ///
    /// - Note: This function autofocuses ([`.autoFocus`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/focusmode/autofocus)) and uses auto-exposure ([`.autoExpose`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposuremode/autoexpose)). If you'd like to pass custom parameters, use ``focus(with:exposureMode:gestureRecognizer:)``.
    ///
    /// - Important: This function is for UIKit. For SwiftUI, see ``focusAndExposeTap(at:)`` and ``focus(with:exposureMode:at:)``.
    ///
    /// - Important: Taps are cut off if they're outside the actual preview area. If there is blank space around the preview, it will still register taps, but those calls will be cut off before focusing actually takes place.
    ///
    /// To use this functionality, call this function from an `@IBAction` outlet function, passing in the `UITapGestureRecognizer` parameter.
    public func focusAndExposeTap(gestureRecognizer: UITapGestureRecognizer) {
        focus(with: .autoFocus, exposureMode: .autoExpose, at: gestureRecognizer.location(in: gestureRecognizer.view))
    }
    
    /// Focuses and exposes the camera from a UIKit `UITapGestureRecognizer` tap.
    ///
    /// - Note: If you'd like to use plain autofocus ([`.autoFocus`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/focusmode/autofocus)) and auto-exposure ([`.autoExpose`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposuremode/autoexpose)), use ``focusAndExposeTap(gestureRecognizer:)``.
    ///
    /// - Important: This function is for UIKit. For SwiftUI, see ``focusAndExposeTap(at:)`` and ``focus(with:exposureMode:at:)``.
    ///
    /// - Important: Taps are cut off if they're outside the actual preview area. If there is blank space around the preview, it will still register taps, but those calls will be cut off before focusing actually takes place.
    ///
    /// To use this functionality, call this function from an `@IBAction` outlet function, passing in the `UITapGestureRecognizer` parameter.
    public func focus(with focusMode: AVCaptureDevice.FocusMode,
                      exposureMode: AVCaptureDevice.ExposureMode,
                      gestureRecognizer: UITapGestureRecognizer) {
        focus(with: focusMode, exposureMode: exposureMode, at: gestureRecognizer.location(in: gestureRecognizer.view), monitorSubjectAreaChange: true)
    }
}

extension AVCaptureViewModel {
    /// Internally used as the backend for ``focusAndExposeTap(gesturePosition:)``, ``focusAndExposeTap(gestureRecognizer:)``, ``focus(with:exposureMode:at:)``, and ``focus(with:exposureMode:gestureRecognizer:)``.
    internal func focus(with focusMode: AVCaptureDevice.FocusMode,
                        exposureMode: AVCaptureDevice.ExposureMode,
                        at previewPoint: CGPoint,
                        monitorSubjectAreaChange: Bool) {
        guard (0.0...1.0).contains(previewPoint.x)
              && (0.0...1.0).contains(previewPoint.y) else { return }
        
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                // Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                // Call set(Focus/Exposure)Mode() to apply the new point of interest.
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = previewPoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = previewPoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
}
