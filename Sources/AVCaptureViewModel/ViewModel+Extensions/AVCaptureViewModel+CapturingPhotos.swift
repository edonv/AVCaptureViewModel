//
//  AVCaptureViewModel+CapturingPhotos.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import SwiftUI
import AVFoundation

// MARK: Capturing Photos

extension AVCaptureViewModel {
    /// Captures a photo.
    ///
    /// After being processed, the captured photo can be accessed from ``lastPhotoCaptured``.
    /// - Note: This *can* be called while video is being captured.
    public func capturePhoto() {
        guard self.photoSettings != nil else {
            print("No photo settings to capture")
            return
        }
        
        // Create a unique settings object for the request.
        let photoSettings = AVCapturePhotoSettings(from: self.photoSettings)
        
        // Provide a unique temporary URL because Live Photo captures can overlap.
        if photoSettings.livePhotoMovieFileURL != nil {
            photoSettings.livePhotoMovieFileURL = uniqueTemporaryDirectoryFileURL()
        }
        
        // TODO: What to do with this for pre-17? as in, what does it do in 17?
        // Start tracking capture readiness on the main thread to synchronously
        // update the shutter button's availability.
//        if #available(iOS 17.0, *) {
//            self.photoOutputReadinessCoordinator.startTrackingCaptureRequest(using: photoSettings)
//        }
        
        sessionQueue.async { [captureOrientation] in
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    // TODO: when iOS 17 is available, confirm if this returns the correct value, even if the the app isn't allowed to rotate
                    // i.e. `videoOrientation` (pre-17) returns `portrait` if the app isn't allowed to rotate even if in landscape
//                    let videoRotationAngle = self.videoDeviceRotationCoordinator.videoRotationAngleForHorizonLevelCapture
                    // TODO: add use of isVideoRotationAngleSupported(videoRotationAngle) on photoOutputConnection
//                    photoOutputConnection.videoRotationAngle = videoRotationAngle
                } else if photoOutputConnection.isVideoOrientationSupported {
                    photoOutputConnection.videoOrientation = captureOrientation
                }
            }
            
            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings,
                                                              tagLocationInCaptures: self.tagLocationInCaptures,
                                                              shouldSaveCapturesToLibrary: self.shouldSaveCapturesToLibrary,
                                                              willCapturePhotoAnimation: {
                // Flash the screen to signal that a photo was captured.
                DispatchQueue.main.async {
                    self.photoCaptureScreenFlashCallback(self.videoPreviewLayer)
                }
            }, livePhotoCaptureHandler: { capturing in
                DispatchQueue.main.async {
                    if capturing {
                        self.inProgressLivePhotoCapturesCount += 1
                    } else {
                        self.inProgressLivePhotoCapturesCount -= 1
                    }
                }
            }, completionHandler: { photoCaptureProcessor in
                // When the capture is complete, remove a reference to the
                // photo capture delegate so it can be deallocated.
                self.sessionQueue.async {
                    self.inProgressPhotoCaptureDelegates.removeValue(forKey: photoCaptureProcessor.requestedPhotoSettings.uniqueID)
                }
                DispatchQueue.main.async {
                    self.lastPhotoCaptured = photoCaptureProcessor.photoData
                }
            })
            
            // Specify the location the photo was taken
            if self.tagLocationInCaptures {
                photoCaptureProcessor.location = self.locationManager.location
            }
            
            // The photo output holds a weak reference to the photo capture
            // delegate and stores it in an array to maintain a strong
            // reference.
            self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
            
            // Stop tracking the capture request because it's now destined for the photo output.
//            if #available(iOS 17.0, *) {
//                self.photoOutputReadinessCoordinator.stopTrackingCaptureRequest(using: photoSettings.uniqueID)
//            }
        }
    }
    
    internal func setUpPhotoSettings() -> AVCapturePhotoSettings {
        var photoSettings = AVCapturePhotoSettings()
        
        // TODO: add code to allow customization of which video format to capture
        // TODO: maybe test with changing device's Camera setting of preferred format (add to Settings?)
        
        // Capture HEIF photos when supported.
        if self.photoOutput.availablePhotoCodecTypes.contains(AVVideoCodecType.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            photoSettings = AVCapturePhotoSettings()
        }
        
        // Set the flash to set flash mode.
        if self.videoDeviceInput.device.isFlashAvailable {
            photoSettings.flashMode = self.flashMode
        }
        
        // Enable high-resolution photos.
        if #available(iOS 16.0, *) {
            photoSettings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
        }
        
        if !photoSettings.availablePreviewPhotoPixelFormatTypes.isEmpty {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
        }
        if isLivePhotoCaptureOn && self.photoOutput.isLivePhotoCaptureSupported {
            // Live Photo Capture is not supported in movie mode.
            photoSettings.livePhotoMovieFileURL = uniqueTemporaryDirectoryFileURL()
        }
        photoSettings.photoQualityPrioritization = self.photoQualityPrioritizationMode
        
        return photoSettings
    }
    
    internal func tenBitVariantOfFormat(activeFormat: AVCaptureDevice.Format) -> AVCaptureDevice.Format? {
        let formats = self.videoDeviceInput.device.formats
        let formatIndex = formats.firstIndex(of: activeFormat)!
        
        let activeDimensions = CMVideoFormatDescriptionGetDimensions(activeFormat.formatDescription)
        let activeMaxFrameRate = activeFormat.videoSupportedFrameRateRanges.last?.maxFrameRate
        let activePixelFormat = CMFormatDescriptionGetMediaSubType(activeFormat.formatDescription)
        
        // AVCaptureDeviceFormats are sorted from smallest to largest in
        // resolution and frame rate. For each resolution and max frame rate
        // there's a cluster of formats that only differ in pixelFormatType.
        // Here, we look for an 'x420' variant of the current activeFormat.
        if activePixelFormat != kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange {
            // Current activeFormat is not a 10-bit HDR format, find its 10-bit
            // HDR variant.
            for index in formatIndex + 1..<formats.count {
                let format = formats[index]
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let maxFrameRate = format.videoSupportedFrameRateRanges.last?.maxFrameRate
                let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
                
                // Don't advance beyond the current format cluster
                if activeMaxFrameRate != maxFrameRate || activeDimensions.width != dimensions.width || activeDimensions.height != dimensions.height {
                    break
                }
                
                if pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange {
                    return format
                }
            }
        } else {
            return activeFormat
        }
        
        return nil
    }
    
    // MARK: HDR Control
    
    /// Call this function to indirectly toggle ``isHDRVideoCaptureOn``.
    public func toggleHDRVideoMode() {
        isHDRVideoCaptureOn.toggle()
    }
    
    internal func hdrVideoModeHasChanged(_ newValue: Bool) {
        if newValue {
            do {
                try self.videoDeviceInput.device.lockForConfiguration()
                if let selectedMovieMode10BitDeviceFormat {
                    self.videoDeviceInput.device.activeFormat = selectedMovieMode10BitDeviceFormat
                }
                self.videoDeviceInput.device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        } else {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            self.session.commitConfiguration()
        }
    }
}
