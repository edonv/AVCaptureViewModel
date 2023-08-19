//
//  AVCaptureViewModel+InputCallbacks.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import SwiftUI
import AVFoundation

extension AVCaptureViewModel {
    // MARK: Resuming an Interrupted Session
    
    /// Call this function to resume a session if it had been interrupted.
    public func resumeInterruptedSession() {
//    @IBAction private func resumeInterruptedSession(_ resumeButton: UIButton) {
        sessionQueue.async {
            // The session might fail to start running, for example, if a phone
            // or FaceTime call is still using audio or video. This failure is
            // communicated by the session posting a runtime error notification.
            // To avoid repeatedly failing to start the session, only try to
            // restart the session in the error handler if you aren't trying to
            // resume the session.
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            if !self.session.isRunning {
                // TODO: state issue here - unable to resume
//                DispatchQueue.main.async {
//                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
//                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
//                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
//                    alertController.addAction(cancelAction)
//                    self.present(alertController, animated: true, completion: nil)
//                }
            } else {
//                DispatchQueue.main.async {
//                    self.resumeButton.isHidden = true
//                }
            }
        }
    }
    
    // MARK: Capture Mode Control
    
    /// Call this function to toggle to the opposite capture mode.
    public func toggleCaptureMode() {
        currentCaptureMode = !currentCaptureMode
    }
    
    internal func captureModeHasChanged(_ newMode: CaptureMode) {
        switch newMode {
        case .photo:
//            recordButton.isEnabled = false
//            HDRVideoModeButton.isHidden = true
            
            selectedMovieMode10BitDeviceFormat = nil
            
            sessionQueue.async {
                // Remove the AVCaptureMovieFileOutput from the session because
                // it doesn't support capture of Live Photos.
                self.session.beginConfiguration()
                if let movieFileOutput = self.movieFileOutput {
                    self.session.removeOutput(movieFileOutput)
                }
                self.session.sessionPreset = .photo
                
//                DispatchQueue.main.async {
//                    captureModeControl.isEnabled = true
//                }
                
                self.movieFileOutput = nil
                
                self.configurePhotoOutput()
                
//                let livePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureEnabled
//                DispatchQueue.main.async {
//                    self.livePhotoModeButton.isHidden = false
//                    self.livePhotoModeButton.isEnabled = livePhotoCaptureEnabled
//                    self.photoQualityPrioritizationSegControl.isHidden = false
//                    self.photoQualityPrioritizationSegControl.isEnabled = true
//                }
                self.session.commitConfiguration()
            }
            
        case .video:
//            livePhotoModeButton.isHidden = true
//            photoQualityPrioritizationSegControl.isHidden = true
            
            sessionQueue.async {
                let movieFileOutput = AVCaptureMovieFileOutput()
                
                if self.session.canAddOutput(movieFileOutput) {
                    self.session.beginConfiguration()
                    self.session.addOutput(movieFileOutput)
                    self.session.sessionPreset = .high
                    
                    self.selectedMovieMode10BitDeviceFormat = self.tenBitVariantOfFormat(activeFormat: self.videoDeviceInput.device.activeFormat)
                    
                    if self.selectedMovieMode10BitDeviceFormat != nil {
                        DispatchQueue.main.async {
//                            self.HDRVideoModeButton.isHidden = false
//                            self.HDRVideoModeButton.isEnabled = true
                        }
                        
                        if self.isHDRVideoCaptureOn {
                            do {
                                try self.videoDeviceInput.device.lockForConfiguration()
                                self.videoDeviceInput.device.activeFormat = self.selectedMovieMode10BitDeviceFormat!
                                print("Setting 'x420' format \(String(describing: self.selectedMovieMode10BitDeviceFormat)) for video recording")
                                self.videoDeviceInput.device.unlockForConfiguration()
                            } catch {
                                print("Could not lock device for configuration: \(error)")
                            }
                        }
                    }
                    
                    if let connection = movieFileOutput.connection(with: .video) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    self.session.commitConfiguration()

//                    DispatchQueue.main.async {
//                        captureModeControl.isEnabled = true
//                    }
                    
                    self.movieFileOutput = movieFileOutput
                    
                    DispatchQueue.main.async {
//                        self.recordButton.isEnabled = true
                        
                        // For photo captures during movie recording, Balanced
                        // quality photo processing is prioritized to get high
                        // quality stills and avoid frame drops during
                        // recording.
                        self.photoQualityPrioritizationMode = .balanced
                    }
                }
            }
        }
    }
    
    internal func configurePhotoOutput() {
        if #available(iOS 16.0, *) {
            let supportedMaxPhotoDimensions = self.videoDeviceInput.device.activeFormat.supportedMaxPhotoDimensions
            let largestDimesnion = supportedMaxPhotoDimensions.last
            self.photoOutput.maxPhotoDimensions = largestDimesnion!
        }
        
        self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported
        self.photoOutput.maxPhotoQualityPrioritization = .quality
        
//        if #available(iOS 17.0, *) {
//            self.photoOutput.isResponsiveCaptureEnabled = self.photoOutput.isResponsiveCaptureSupported
//            self.photoOutput.isFastCapturePrioritizationEnabled = self.photoOutput.isFastCapturePrioritizationSupported
//            self.photoOutput.isAutoDeferredPhotoDeliveryEnabled = self.photoOutput.isAutoDeferredPhotoDeliverySupported
//        }
        
        let photoSettings = self.setUpPhotoSettings()
        DispatchQueue.main.async {
            self.photoSettings = photoSettings
        }
    }
}
