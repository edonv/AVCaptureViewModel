//
//  AVCaptureViewModel.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import SwiftUI
import AVFoundation
import CoreLocation
import Combine

//@MainActor
/// An `ObservableObject` with exposed `@Published` properties to be used with ``CameraPreview`` (SwiftUI) or ``CameraPreviewView`` (UIKit).
///
/// `AVCaptureViewModel` allows you to build a custom interface around a ``CameraPreview`` (SwiftUI) or a ``CameraPreviewView`` (UIKit) as part of a larger `View` or `UIViewController` (respectively) for capturing photos and videos.
///
/// > Important: While it's not always necessary request permissions for current location (``settings-swift.property``.``Settings-swift.struct/tagLocationInCaptures`` can be set to `false`), camera permissions are required ([`NSCameraUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nscamerausagedescription)). Additionally, microphone permissions are optional, but recommended, as it's needed to capture audio for Live Photos and movies ([`NSMicrophoneUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nsmicrophoneusagedescription)).
public class AVCaptureViewModel: NSObject, ObservableObject {
    // MARK: Private/Internal Properties
    
    internal let locationManager = CLLocationManager()
    
    // MARK: Public Properties
    
    // TODO: maybe move properties into a Settings struct that is edited in a closure in init
    
    /// General preferences for the view model. See its documentation for more info.
    public var settings: Settings
    
    /// The preview layer's capture session.
    ///
    /// ## Usage:
    /// - term SwiftUI: ``CameraPreview/session`` must be set to this via ``CameraPreview/init(videoPreviewLayer:session:)``.
    /// - term UIKit: ``CameraPreviewView/session`` must be set to this directly.
    public private(set) var session = AVCaptureSession()
    
    /// The linked view preview `CALayer`.
    ///
    /// ## Usage:
    /// - term SwiftUI: This must be set to ``CameraPreview/videoPreviewLayer`` via ``CameraPreview/init(videoPreviewLayer:session:)``.
    /// - term UIKit: This must be set to ``CameraPreviewView/videoPreviewLayer`` directly.
    public var videoPreviewLayer: AVCaptureVideoPreviewLayer! {
        didSet {
            guard videoPreviewLayer != nil else { return }
            sessionQueue.async { [weak self] in
                self?.addKVOObservers()
            }
        }
    }

    // MARK: Public Published Properties
    
    // TODO: refactor `uiIsEnabled` in relation to state changes and enabling/disabling buttons in UI
    @Published public var uiIsEnabled: Bool
    
    // TODO: properties relating to camera settings/formats
    
    // TODO: property relating to requesting permissions manually
    
    // TODO: property for setting the active camera (front/back)
    
    // MARK: Life Cycle
    
    /// Create the view model.
    /// - Parameter settingsHandler: Use this handler to set preferences for the view model.
    public init(_ settingsHandler: (_ settings: inout Settings) -> ()) {
        self.settings = Settings()
        settingsHandler(&self.settings)
        
        // Disable the UI. Enable the UI later, if and only if the session starts running.
        self.uiIsEnabled = false
        
        super.init()
        
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
        
        // Combine Observers
        setUpObservers()
    }
    
    // MARK: - Observers
    
    private func setUpObservers() {
        // Only setup observers and start the session if setup
        // succeeded.
        $setupResult
            .filter { $0 == .success }
            .first()
            .receive(on: sessionQueue)
            .sink { _ in
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            }
            .store(in: &observers)
        
        $currentCaptureMode
            // Dropping first value so this isn't called on launch.
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: captureModeHasChanged(_:))
            .store(in: &observers)
        
        Publishers.Merge(
            $isLivePhotoCaptureOn
                .map { _ in () },
            $photoQualityPrioritizationMode
                .map { _ in () }
        )
        .receive(on: sessionQueue)
        .map { self.setUpPhotoSettings() }
        .receive(on: DispatchQueue.main)
        .sink { self.photoSettings = $0 }
        .store(in: &observers)
        
        $isHDRVideoCaptureOn
            // Dropping first value so this isn't called on launch.
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: hdrVideoModeHasChanged(_:))
            .store(in: &observers)
        
        let currentlyCapturingLivePhotos = $inProgressLivePhotoCapturesCount
            .map { $0 > 0 }
            .receive(on: DispatchQueue.main)
        
        if #available(iOS 14, *) {
            currentlyCapturingLivePhotos
                .assign(to: &$currentlyCapturingLivePhotos)
        } else {
            currentlyCapturingLivePhotos
                .sink { [weak self] newValue in
                    self?.currentlyCapturingLivePhotos = newValue
                }
                .store(in: &observers)
        }
        
        // Observing changes to device orientation
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        let orientationChanges = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .handleEvents(receiveCancel: {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
            })
            .compactMap { $0.object as? UIDevice }
            .map(\.orientation)
            .receive(on: DispatchQueue.main)
        
        if #available(iOS 14, *) {
            orientationChanges
                .assign(to: &$currentDeviceOrientation)
        } else {
            orientationChanges
                .sink { [weak self] newValue in
                    self?.currentDeviceOrientation = newValue
                }
                .store(in: &observers)
        }
    }
    
    #warning("maybe remove this?")
    /// Call this function once you're ready to start showing the camera preview.
    public func requestPermissions() {
        // Request location authorization so photos and videos can be tagged
        // with their location.
        if settings.tagLocationInCaptures {
            if #available(iOS 14.0, *) {
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                }
            } else {
                if CLLocationManager.authorizationStatus() == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                }
            }
        }
        
        // Check the video authorization status. Video access is required and
        // audio access is optional. If the user denies audio access, AVCam
        // won't record audio during movie recording.
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break

        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.

             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            }

        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
    }
    
    // MARK: Session Management
    
    internal enum SessionSetupResult {
        case initial
        case success
        case notAuthorized
        case configurationFailed
    }
    
    internal var isSessionRunning = false
    
    // Communicate with the session and other session objects on this queue.
    internal let sessionQueue = DispatchQueue(label: "com.AVCaptureViewModel")
    
    @Published internal var setupResult: SessionSetupResult = .initial
    
    internal var videoDeviceInput: AVCaptureDeviceInput!
    
    // MARK: - configureSession()
    
    // Call this on the session queue.
    private func configureSession() {
        if ![.success, .initial].contains(setupResult) {
            return
        }
        
        session.beginConfiguration()
        
        // Do not create an AVCaptureMovieFileOutput when setting up the session
        // because Live Photo is not supported when AVCaptureMovieFileOutput is
        // added to the session.
        session.sessionPreset = .photo
        
        // Add video input.
        do {
            // Handle the situation when the system-preferred camera is nil.
            var defaultVideoDevice: AVCaptureDevice?
//            if #available(iOS 17.0, *) {
//                defaultVideoDevice = AVCaptureDevice.systemPreferredCamera
//            } else {
            defaultVideoDevice = AVCaptureDevice.default(for: .video)
//            }
            
            let userDefaults = UserDefaults.standard
            if !userDefaults.bool(forKey: "setInitialUserPreferredCamera") || defaultVideoDevice == nil {
                let backVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
                    mediaType: .video,
                    position: .back
                )
                
                defaultVideoDevice = backVideoDeviceDiscoverySession.devices.first
                
//                if #available(iOS 17.0, *) {
//                    AVCaptureDevice.userPreferredCamera = defaultVideoDevice
//                }
                
                userDefaults.set(true, forKey: "setInitialUserPreferredCamera")
            }
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                session.commitConfiguration()
                setupResult = .configurationFailed
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            // TODO: after updating to Xcode 15, figure out which KVO observer pattern works
//            if #available(iOS 17, *) {
//                AVCaptureDevice.self.publisher(for: \.systemPreferredCamera, options: .new)
//                    .map(<#T##keyPath: KeyPath<AVCaptureDevice?, T>##KeyPath<AVCaptureDevice?, T>#>)
//
//                //            AVCaptureDevice.self.addObserver(self, forKeyPath: "systemPreferredCamera", options: [.new], context: &systemPreferredCameraContext)
//            }
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
//                if #available(iOS 17.0, *) {
//                    DispatchQueue.main.async {
//                        // Dispatch video streaming to the main queue because
//                        // AVCaptureVideoPreviewLayer is the backing layer for
//                        // CameraPreviewView. You can manipulate UIView only on the main
//                        // thread. Note: As an exception to the above rule, it's not
//                        // necessary to serialize video orientation changes on the
//                        // AVCaptureVideoPreviewLayer’s connection with other
//                        // session manipulation.
//                        self.createDeviceRotationCoordinator()
//                    }
//                }
            } else {
                print("Couldn't add video device input to the session.")
                session.commitConfiguration()
                setupResult = .configurationFailed
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            session.commitConfiguration()
            setupResult = .configurationFailed
            return
        }
        
        // Add an audio input device.
        do {
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                
                if session.canAddInput(audioDeviceInput) {
                    session.addInput(audioDeviceInput)
                } else {
                    print("Could not add audio device input to the session")
                }
            }
        } catch {
            print("Could not create audio device input: \(error)")
        }
        
        // Add the photo output.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            DispatchQueue.main.async {
                self.isLivePhotoCaptureOn = self.photoOutput.isLivePhotoCaptureSupported
                self.photoQualityPrioritizationMode = .balanced
            }
            
            self.configurePhotoOutput()
            
//            if #available(iOS 17.0, *) {
//                let readinessCoordinator = AVCapturePhotoOutputReadinessCoordinator(photoOutput: photoOutput)
//                DispatchQueue.main.async {
//                    self.photoOutputReadinessCoordinator = readinessCoordinator
//                    readinessCoordinator.delegate = self
//                }
//            }
        } else {
            print("Could not add photo output to the session")
            session.commitConfiguration()
            setupResult = .configurationFailed
            return
        }
        
        session.commitConfiguration()
        DispatchQueue.main.sync {
            self.setupResult = .success
        }
    }
    
    // MARK: - Button Presses (Input Callbacks)
    
    /// Describes the type of media the session is set to capture.
    public enum CaptureMode {
        case photo
        case video
        
        /// Performs a logical NOT operation on a `CaptureMode` value.
        ///
        /// Returns the opposite or other value.
        static public prefix func !(mode: CaptureMode) -> CaptureMode {
            switch mode {
            case .photo: return .video
            case .video: return .photo
            }
        }
    }
    
    /// The currently-active ``CaptureMode``.
    ///
    /// Changes to this property will automatically update the session as needed, and these changes will be made from the correct threads.
    ///
    /// You can use this property is different ways:
    /// - When using SwiftUI, bind this to a [`Picker`](https://developer.apple.com/documentation/swiftui/picker).
    /// - When using UIKit, create a `@IBAction` outlet function from a [`UISegmentedControl`](https://developer.apple.com/documentation/uikit/uisegmentedcontrol) and update this property from there.
    /// - You can set this property directly.
    ///
    /// - Important: You can also listen to changes to this property using SwiftUI's `.onReceive(_:perform:)` view modifier.
    @Published public var currentCaptureMode: CaptureMode = .photo
    
    // MARK: Device Configuration
    
    /// Returns `true` if the device has more than 1 camera.
    ///
    /// This property can be used to determine if a button intended to change cameras should be visible or hidden.
    public var deviceCanChangeCamera: Bool {
        videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
    }
    
    internal let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
        mediaType: .video,
        position: .unspecified
    )
    
//    @available(iOS 17.0, *)
//    internal var videoDeviceRotationCoordinator: AVCaptureDevice.RotationCoordinator!
    
    @Published public var currentDeviceOrientation: UIDeviceOrientation = .unknown
    internal var captureOrientation: AVCaptureVideoOrientation {
        switch currentDeviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            // This value is meant to be backwards
            return .landscapeRight
        case .landscapeRight:
            // This value is meant to be backwards
            return .landscapeLeft
        default:
            return .portrait
        }
    }
    
    // MARK: Readiness Coordinator
    // no stored properties
    
    // MARK: Tap and Focus
    // no stored properties
    
    // MARK: Capturing Photos
    
    #warning("TODO: Test if this works even with rapid fire image capture.")
    
    /// Image data of the latest photo captured.
    ///
    /// - Note: If you need a captured photo immediatley after capture (rather than need it saved to the user's photo library automatically), you should subscribe to changes to this property using SwiftUI's `.onReceive(_:perform:)` view modifier. Or in UIKit, you can use Combine to subscribe to changes to this property.
    @Published public var lastPhotoCaptured: Data? = nil
    
    internal let photoOutput = AVCapturePhotoOutput()
    
//    @available(iOS 17.0, *)
//    internal var photoOutputReadinessCoordinator: AVCapturePhotoOutputReadinessCoordinator!
    
    internal var photoSettings: AVCapturePhotoSettings!
    
    internal var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    /// The current flash mode.
    ///
    /// Set this property to change the type of flash when capturing.
    ///
    /// - Note: This will only be used if the active capture device can use a flash ([`isFlashAvailable`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/1624627-isflashavailable)).
    ///
    /// > See More: [`flashMode`](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/1648760-flashmode).
    @Published public var flashMode: AVCaptureDevice.FlashMode = .auto
    
    /// Whether the active session is capturing Live Photos.
    ///
    /// Changes to this property will automatically update the session as needed, and these changes will be made from the correct threads.
    ///
    /// - Note: When using SwiftUI, you can bind this to a `Toggle`. Alternatively (in SwiftUI or UIKit), you can also set it manually (i.e. `isLivePhotoCaptureOn = !isLivePhotoCaptureOn`).
    ///
    /// - Important: You can also listen to changes to this property using SwiftUI's `.onReceive(_:perform:)` view modifier.
    @Published public var isLivePhotoCaptureOn = false
    
    /// A setting that indicates how to prioritize photo quality against speed of photo delivery.
    ///
    /// For more info, see [`AVCapturePhotoSettings.photoQualityPrioritization`](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/3183000-photoqualityprioritization).
    @Published public var photoQualityPrioritizationMode: AVCapturePhotoOutput.QualityPrioritization = .balanced
    
    #warning("add Published properties for state/processingPhoto (or isCapturingPhoto) and isCapturingVideo or events (maybe via a subject)")
    
    internal var selectedMovieMode10BitDeviceFormat: AVCaptureDevice.Format?
    
    /// Whether the active session is capturing HDR video.
    ///
    /// This propery will still be `true` when ``currentCaptureMode`` is set to ``CaptureMode/photo``.
    ///
    /// Changes to this property will automatically update the session as needed, and these changes will be made from the correct threads.
    ///
    /// - Note: When using SwiftUI, you can bind this to a `Toggle`. Alternatively (in SwiftUI or UIKit), you can also set it manually (i.e. `isHDRVideoCaptureOn = !isHDRVideoCaptureOn`, or using ``toggleHDRVideoMode()``).
    @Published public var isHDRVideoCaptureOn = true
    
    /// This is used internally to keep track of how many Live Photos are actively being captured and to to set ``currentlyCapturingLivePhotos``.
    @Published internal var inProgressLivePhotoCapturesCount = 0
    
    #warning("after adding State, does this still need to exist?")
    /// If there is a Live Photo actively being captured. There can be real-time overlap.
    @Published public var currentlyCapturingLivePhotos = false
    
    // MARK: Recording Movies
    
    /// A local `URL` to the latest video captured.
    ///
    /// After being captured, it's saved to a temporary file until it's cleaned up by ``cleanUpCapturedMovie(at:)``. Once it's cleaned up, this is set back to `nil`.
    /// - Note: If you need a captured video immediately after capture (rather than need it saved to the user's photo library automatically), you should subscribe to changes to this property using SwiftUI's `.onReceive(_:perform:)` view modifier.
    /// - Important: In the above scenario, you **must** set ``settings-swift.property``'s ``Settings-swift.struct/shouldCleanUpMoviesAutomatically`` to `false`, then be sure to call ``cleanUpCapturedMovie(at:)`` when you're finished doing what you need with the movie file.
    @Published public var lastMovieCaptured: URL? = nil
    
    /// This is used internally to keep track of all movies saved to temporary files that haven't been cleaned up.
    internal var capturedMovieURLs: Set<URL> = []
    
    internal var movieFileOutput: AVCaptureMovieFileOutput?
    
    internal var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    /// When `true`, the session is actively changing cameras.
    ///
    /// This can be used to disable camera buttons, as input cannot be captured while in this state.
    @Published public var currentlyChangingCameras = false
    
    // TODO: what to do with this
    var _supportedInterfaceOrientations: UIInterfaceOrientationMask = .all
    var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get { return _supportedInterfaceOrientations }
        set { _supportedInterfaceOrientations = newValue }
    }
    
    // MARK: Shared w/ Photos/Movies
    
    internal func uniqueTemporaryDirectoryFileURL() -> URL {
        let fileName = UUID().uuidString
        
        if #available(iOS 16, *) {
            return FileManager.default.temporaryDirectory
                .appending(component: fileName, directoryHint: .notDirectory)
                .appendingPathExtension("mov")
        } else {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
                .appendingPathExtension("mov")
        }
    }
    
    // MARK: KVO and Notifications
    
    /// Used internally for Combine subscriptions.
    internal var observers = Set<AnyCancellable>()
}
