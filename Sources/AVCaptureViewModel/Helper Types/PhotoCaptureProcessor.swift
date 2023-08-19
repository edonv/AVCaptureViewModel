/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's photo capture delegate object.
*/

import AVFoundation
import Photos

class PhotoCaptureProcessor: NSObject {
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    internal var tagLocationInCaptures: Bool
    
    internal var shouldSaveCapturesToLibrary: Bool
    
    private let willCapturePhotoAnimation: () -> Void
    
    private let livePhotoCaptureHandler: (Bool) -> Void
    
    lazy var context = CIContext()
    
    private let completionHandler: (PhotoCaptureProcessor) -> Void
    
    internal var photoData: Data?
    
    private var livePhotoCompanionMovieURL: URL?
    
    // Save the location of captured photos.
    var location: CLLocation?

    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         tagLocationInCaptures: Bool,
         shouldSaveCapturesToLibrary: Bool,
         willCapturePhotoAnimation: @escaping () -> Void,
         livePhotoCaptureHandler: @escaping (Bool) -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor) -> Void) {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.tagLocationInCaptures = tagLocationInCaptures
        self.shouldSaveCapturesToLibrary = shouldSaveCapturesToLibrary
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.livePhotoCaptureHandler = livePhotoCaptureHandler
        self.completionHandler = completionHandler
    }
    
    private func didFinish() {
        if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
            if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath) {
                do {
                    try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
                } catch {
                    print("Could not remove file at url: \(livePhotoCompanionMoviePath)")
                }
            }
        }
        
        completionHandler(self)
    }
}

/// This extension adopts all of the AVCapturePhotoCaptureDelegate protocol methods.
extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    /// - Tag: WillBeginCapture
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if resolvedSettings.livePhotoMovieDimensions.width > 0 && resolvedSettings.livePhotoMovieDimensions.height > 0 {
            livePhotoCaptureHandler(true)
        }
    }
    
    /// - Tag: WillCapturePhoto
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
    }
    
    /// - Tag: DidFinishProcessingPhoto
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        self.photoData = photo.fileDataRepresentation()
    }
    
//    @available(iOS 17, *)
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?, error: Error?) {
//        if let error = error {
//            print("Error capturing deferred photo: \(error)")
//            return
//        }
//
//        self.photoData = deferredPhotoProxy?.fileDataRepresentation()
//    }
    
    /// - Tag: DidFinishRecordingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        livePhotoCaptureHandler(false)
    }
    
    /// - Tag: DidFinishProcessingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            print("Error processing Live Photo companion movie: \(String(describing: error))")
            return
        }
        livePhotoCompanionMovieURL = outputFileURL
    }
    
    /// - Tag: DidFinishCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            didFinish()
            return
        }

        guard photoData != nil else {
            print("No photo data resource")
            didFinish()
            return
        }
        
        guard shouldSaveCapturesToLibrary else {
            print("Finished capturing, not saving to library.")
            didFinish()
            return
        }
        
        let authRequestCallback = { (status: PHAuthorizationStatus) -> Void in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges {
                    let options = PHAssetResourceCreationOptions()
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue }
                    
                    let resourceType = PHAssetResourceType.photo
//                    if #available(iOS 17, *)
//                        && (resolvedSettings.deferredPhotoProxyDimensions.width > 0)
//                        && (resolvedSettings.deferredPhotoProxyDimensions.height > 0) {
//                        resourceType = PHAssetResourceType.photoProxy
//                    }
                    creationRequest.addResource(with: resourceType, data: self.photoData!, options: options)
                    
                    // Specify the location in which the photo was taken (if set to).
                    if self.tagLocationInCaptures {
                        creationRequest.location = self.location
                    }
                    
                    if let livePhotoCompanionMovieURL = self.livePhotoCompanionMovieURL {
                        let livePhotoCompanionMovieFileOptions = PHAssetResourceCreationOptions()
                        livePhotoCompanionMovieFileOptions.shouldMoveFile = true
                        creationRequest.addResource(with: .pairedVideo,
                                                    fileURL: livePhotoCompanionMovieURL,
                                                    options: livePhotoCompanionMovieFileOptions)
                    }
                    
                } completionHandler: { _, error in
                    if let error = error {
                        print("Error occurred while saving photo to photo library: \(error)")
                    }
                    
                    self.didFinish()
                }
            } else {
                self.didFinish()
            }
        }
        
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: authRequestCallback)
        } else {
            PHPhotoLibrary.requestAuthorization(authRequestCallback)
        }
    }
}
