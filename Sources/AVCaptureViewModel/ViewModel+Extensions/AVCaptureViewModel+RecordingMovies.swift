//
//  AVCaptureViewModel+RecordingMovies.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import SwiftUI
import AVFoundation
import Photos

// MARK: Recording Movies

extension AVCaptureViewModel: AVCaptureFileOutputRecordingDelegate {
    /// Starts/stops video capture recording video.
    ///
    /// - Note: Because a unique file path is used for each recording, a new recording won't overwrite a recording mid-save.
    public func toggleMovieRecording() {
        guard let movieFileOutput = self.movieFileOutput else {
            return
        }
        
        /*
         Disable the Camera button until recording finishes, and disable
         the Record button until recording starts or finishes.
         
         See the AVCaptureFileOutputRecordingDelegate methods.
         */
//        cameraButton.isEnabled = false
//        recordButton.isEnabled = false
//        captureModeControl.isEnabled = false
        
        // This disables device rotation while video is being captured.
        if let scene = UIApplication.shared.connectedScenes.first,
           let windowScene = scene as? UIWindowScene {
            switch windowScene.interfaceOrientation {
            case .portrait: self.supportedInterfaceOrientations = .portrait
            case .landscapeLeft: self.supportedInterfaceOrientations = .landscapeLeft
            case .landscapeRight: self.supportedInterfaceOrientations = .landscapeRight
            case .portraitUpsideDown: self.supportedInterfaceOrientations = .portraitUpsideDown
            case .unknown: self.supportedInterfaceOrientations = .portrait
            default: self.supportedInterfaceOrientations = .portrait
            }
        }
        
        // This is to force update changes to orientation (from switch above)
        // Might not actually use this
        // TODO: how to do this before 16? and how to do this from SwiftUI?
//        if #available(iOS 16.0, *) {
//            self.setNeedsUpdateOfSupportedInterfaceOrientations()
//        } else {
//            // Fallback on earlier versions
//
//        }
        
        sessionQueue.async {
            if !movieFileOutput.isRecording {
                if UIDevice.current.isMultitaskingSupported {
                    self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                }
                
                let movieFileOutputConnection = movieFileOutput.connection(with: .video)
                
                // Update the orientation on the movie file output video
                // connection before recording.
                if #available(iOS 17.0, *) {
//                    let videoRotationAngle = self.videoDeviceRotationCoordinator.videoRotationAngleForHorizonLevelCapture
//
//                    movieFileOutputConnection?.videoRotationAngle = videoRotationAngle
                } else if let videoOrientation = self.videoPreviewLayer.connection?.videoOrientation {
                    // https://developer.apple.com/documentation/avfoundation/capture_setup/setting_up_a_capture_session
                    // the link might say to do something else, but for now trying to mimic logic from iOS 17 code
//                    let videoOrientation = self.videoDeviceRotationCoordinator.videoRotationAngleForHorizonLevelCapture
                    
                    movieFileOutputConnection?.videoOrientation = videoOrientation
                }
                
                // TODO: if making this a package, make sure to make this an option
                // Sets output settings to .hevc if device supports. We need to keep it with jpeg
                let availableVideoCodecTypes = movieFileOutput.availableVideoCodecTypes
                if availableVideoCodecTypes.contains(.hevc) {
                    movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
                }
                
                // Start recording video to a temporary file.
                movieFileOutput.startRecording(to: self.uniqueTemporaryDirectoryFileURL(), recordingDelegate: self)
            } else {
                movieFileOutput.stopRecording()
            }
        }
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    
    #warning("Make this an event")
    
    /// - Tag: DidStartRecording
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        capturedMovieURLs.insert(fileURL)
        
        // Enable the Record button to let the user stop recording.
//        DispatchQueue.main.async {
//            self.recordButton.isEnabled = true
//            self.recordButton.setImage(#imageLiteral(resourceName: "CaptureStop"), for: [])
//        }
    }
    
    #warning("Make this an event")

    /// - Tag: DidFinishRecording
    public func fileOutput(_ output: AVCaptureFileOutput,
                           didFinishRecordingTo outputFileURL: URL,
                           from connections: [AVCaptureConnection],
                           error: Error?) {
        let cleanUp = { (url: URL) -> Void in
            guard self.shouldCleanUpMoviesAutomatically else { return }
            self.cleanUpCapturedMovie(at: url)
        }
        
        var success = true
        
        if let error {
            print("Movie file finishing error: \(String(describing: error))")
            success = (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as! Bool
        }
        
        if success && shouldSaveCapturesToLibrary {
            self.lastMovieCaptured = outputFileURL
            
            // Check the authorization status.
            let authRequestCallback = { [shouldCleanUpMoviesAutomatically] (status: PHAuthorizationStatus) -> Void in
                if status == .authorized {
                    // Save the movie file to the photo library and cleanup.
                    PHPhotoLibrary.shared().performChanges {
                        let options = PHAssetResourceCreationOptions()
                        
                        // Only move the file (as opposed to copying) if `shouldCleanUpMoviesAutomatically` is set to `true`
                        options.shouldMoveFile = shouldCleanUpMoviesAutomatically
                        
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
                        
                        // Specify the movie's location.
                        creationRequest.location = self.locationManager.location
                    } completionHandler: { success, error in
                        if !success {
                            print("Couldn't save the movie to your photo library: \(String(describing: error))")
                        }
                        cleanUp(outputFileURL)
                    }
                } else {
                    cleanUp(outputFileURL)
                }
            }
            
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: authRequestCallback)
            } else {
                PHPhotoLibrary.requestAuthorization(authRequestCallback)
            }
        } else {
            cleanUp(outputFileURL)
        }
        
        // When recording finishes, check if the system-preferred camera
        // changed during the recording.
//        if #available(iOS 17.0, *) {
//            sessionQueue.async {
//                let systemPreferredCamera = AVCaptureDevice.systemPreferredCamera
//                if self.videoDeviceInput.device != systemPreferredCamera {
//                    self.changeCamera(systemPreferredCamera, isUserSelection: false)
//                }
//            }
//        }
        
        // Enable the Camera and Record buttons to let the user switch camera
        // and start another recording.
        
        DispatchQueue.main.async {
            #warning("push an event")
            // Only enable the ability to change camera if the device has more
            // than one camera.
//            self.cameraButton.isEnabled = self.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
//            self.recordButton.isEnabled = true
//            self.captureModeControl.isEnabled = true
//            self.recordButton.setImage(#imageLiteral(resourceName: "CaptureVideo"), for: [])
            self.supportedInterfaceOrientations = UIInterfaceOrientationMask.all
            
            // After the recording finishes, allow rotation to continue.
            // This is to flip orientation sideways
            // Might not actually use this
            // TODO: how to do this before 16?
            if #available(iOS 16.0, *) {
//                self.setNeedsUpdateOfSupportedInterfaceOrientations()
            } else {
                
            }
        }
    }
    
    /// This is used to delete the video captures from its tepmorary location after it's been used.
    ///
    /// By default, this is called automatically after the movie has been moved to the device's photo library.
    ///
    /// > Important: If ``settings-swift.property``.``Settings-swift.struct/shouldCleanUpMoviesAutomatically`` is set to `false`, this won't get called automatically. In that case, you must be sure to call this function after your done with the captured video.
    /// - Note: Because we use a unique file path for each recording, a new recording won't overwrite a recording mid-save.
    public func cleanUpCapturedMovie(at outputFileURL: URL) {
        let path = outputFileURL.path
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                print("Could not remove file at url: \(outputFileURL)")
            }
        }
        
        if let currentBackgroundRecordingID = backgroundRecordingID {
            backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
            
            if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
            }
        }
        
        capturedMovieURLs.remove(outputFileURL)
    }
    
    /// Call this function to clean up all leftover captured movies from temporary files.
    ///
    /// This function can be used as a back-up if you aren't able to keep track of URLs for calling ``cleanUpCapturedMovie(at:)``.
    public func cleanUpAllCapturedMovies() {
        capturedMovieURLs.forEach(cleanUpCapturedMovie(at:))
        capturedMovieURLs.removeAll()
    }
}
