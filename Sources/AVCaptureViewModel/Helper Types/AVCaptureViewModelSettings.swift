//
//  AVCaptureViewModelSettings.swift
//  
//
//  Created by Edon Valdman on 8/19/23.
//

import UIKit
import AVFoundation

extension AVCaptureViewModel {
    public struct Settings {
        /// Dictates if the device's currently location should be attached to captures.
        ///
        /// Default is `false`.
        ///
        /// - Important: When set to `true`, permission is needed from the user ([`NSLocationWhenInUseUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nslocationwheninuseusagedescription)). Otherwise, it will crash.
        public var tagLocationInCaptures: Bool = false
        
        /// Dictates if captures should be automatically saved to the device's photo library.
        ///
        /// Default is `false`.
        ///
        /// - Important: When set to `true`, permission is needed from the user ([`NSPhotoLibraryUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nsphotolibraryusagedescription)). Otherwise, it will crash.
        public var shouldSaveCapturesToLibrary: Bool = false
        
        /// Dictates if video captures should be automatically cleared from their temporary file after being processed.
        ///
        /// Default is `true`.
        ///
        /// If you want access to video captures directly without having to access them from the user's photo library, set this to `false`, then subscribe to changes to ``AVCaptureViewModel/AVCaptureViewModel/lastMovieCaptured``.
        ///
        /// - Important: When set to `false`, you must be sure to call ``AVCaptureViewModel/AVCaptureViewModel/cleanUpCapturedMovie(at:)`` once you're finished copying the capture from its location, feeding the function the capture's `URL`.
        public var shouldCleanUpMoviesAutomatically: Bool = true
        
        /// The callback for when ``AVCaptureViewModel/AVCaptureViewModel/capturePhoto()`` is called.
        ///
        /// This can be overridden to do custom animations, or made empty to eliminate a screen flash animation altogether.
        ///
        /// The default animation is:
        /// ```swift
        /// { (videoPreviewLayer: AVCaptureVideoPreviewLayer) in
        ///     videoPreviewLayer.opacity = 0
        ///     UIView.animate(withDuration: 0.25) {
        ///         videoPreviewLayer.opacity = 1
        ///     }
        /// }
        /// ```
        ///
        /// - Note: This callback is called on the main thread.
        public var photoCaptureScreenFlashCallback: (_ videoPreviewLayer: AVCaptureVideoPreviewLayer) -> Void = { videoPreviewLayer in
            videoPreviewLayer.opacity = 0
            UIView.animate(withDuration: 0.25) {
                videoPreviewLayer.opacity = 1
            }
        }
        
        #warning("selfie camera is mirrored (use AVCaptureConnection.isVideoMirrored)")
    }
    
    /// Convenience getter for ``settings``'s ``Settings/tagLocationInCaptures``.
    internal var tagLocationInCaptures: Bool {
        settings.tagLocationInCaptures
    }
    
    /// Convenience getter for ``settings``'s ``Settings/shouldSaveCapturesToLibrary``.
    internal var shouldSaveCapturesToLibrary: Bool {
        settings.shouldSaveCapturesToLibrary
    }
    
    /// Convenience getter for ``settings``'s ``Settings/shouldCleanUpMoviesAutomatically``.
    internal var shouldCleanUpMoviesAutomatically: Bool {
        settings.shouldCleanUpMoviesAutomatically
    }
    
    /// Convenience getter/setter for ``settings``'s ``Settings/photoCaptureScreenFlashCallback``.
    internal var photoCaptureScreenFlashCallback: (_ videoPreviewLayer: AVCaptureVideoPreviewLayer) -> Void {
        get {
            settings.photoCaptureScreenFlashCallback
        } set {
            settings.photoCaptureScreenFlashCallback = newValue
        }
    }
}
