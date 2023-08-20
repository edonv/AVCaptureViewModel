//
//  AVCaptureViewModel+DeviceConfig.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import SwiftUI
import AVFoundation

extension AVCaptureViewModel {
    // TODO: what to do with these state changes? view modifier callbacks?
    
    /// Call this function to cycle through available cameras.
    ///
    /// Most commonly, this will be used to swap between front and back cameras.
    public func changeCameraToNext() {
        self.currentlyChangingCameras = true
        self.selectedMovieMode10BitDeviceFormat = nil
        self.changeCamera(nil, isUserSelection: true) { [weak self] in
            self?.currentlyChangingCameras = false
        }
    }
    
    private func changeCamera(_ videoDevice: AVCaptureDevice?, isUserSelection: Bool, completion: (() -> Void)? = nil) {
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let newVideoDevice: AVCaptureDevice?
            
            if let videoDevice = videoDevice {
                newVideoDevice = videoDevice
            } else {
                let currentPosition = currentVideoDevice.position
                
                let backVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
                                                                                       mediaType: .video, position: .back)
                let frontVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera],
                                                                                        mediaType: .video, position: .front)
                
                let externalVideoDeviceDiscoverySession: AVCaptureDevice.DiscoverySession? = nil
//                if #available(iOS 17, *) {
//                    externalVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.external],
//                                                                                           mediaType: .video,
//                                                                                           position: .unspecified)
//                }
                
                switch currentPosition {
                case .unspecified, .front:
                    newVideoDevice = backVideoDeviceDiscoverySession.devices.first
                    
                case .back:
                    if let externalVideoDeviceDiscoverySession,
                       let externalCamera = externalVideoDeviceDiscoverySession.devices.first {
                        newVideoDevice = externalCamera
                    } else {
                        newVideoDevice = frontVideoDeviceDiscoverySession.devices.first
                    }
                    
                @unknown default:
                    print("Unknown capture position. Defaulting to back, dual-camera.")
                    newVideoDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
                }
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.session.beginConfiguration()
                    
                    // Remove the existing device input first, because
                    // AVCaptureSession doesn't support simultaneous use of the
                    // rear and front cameras.
                    self.session.removeInput(self.videoDeviceInput)
                    
                    if self.session.canAddInput(videoDeviceInput) {
                        NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)
                        NotificationCenter.default.addObserver(forName: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device, queue: nil, using: self.subjectAreaDidChange(notification:))

                        self.session.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                        
//                        if #available(iOS 17, *) {
//                            if isUserSelection {
//                                AVCaptureDevice.userPreferredCamera = videoDevice
//                            }
//
//                            DispatchQueue.main.async {
//                                self.createDeviceRotationCoordinator()
//                            }
//                        }
                    } else {
                        self.session.addInput(self.videoDeviceInput)
                    }
                    if let connection = self.movieFileOutput?.connection(with: .video) {
                        self.session.sessionPreset = .high
                        
                        self.selectedMovieMode10BitDeviceFormat = self.tenBitVariantOfFormat(activeFormat: self.videoDeviceInput.device.activeFormat)
                        
                        if self.selectedMovieMode10BitDeviceFormat != nil {
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
                        
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    
                    // `livePhotoCaptureEnabled` and other properties of
                    // the`AVCapturePhotoOutput` are `NO` when a video device
                    // disconnects from the session. After the session acquires
                    // a new video device, you need to reconfigure the photo
                    // output to enable those properties, if applicable.
                    self.configurePhotoOutput()
                    
                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }
            
            completion?()
        }
    }
}
