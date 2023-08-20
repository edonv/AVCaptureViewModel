//
//  AVCaptureViewModel+KVO.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import Foundation
import AVFoundation

// MARK: - KVO and Notifications

// MARK: - Adding/Removing Observers

extension AVCaptureViewModel {
    /// - Tag: ObserveInterruption
    internal func addKVOObservers() {
        // TODO: Once the commented-out code is removed, zipping in `.isLivePhotoCaptureEnabled` can be removed too
        session.publisher(for: \.isRunning, options: .new)
            .map { ($0, self.photoOutput.isLivePhotoCaptureEnabled) }
            .receive(on: DispatchQueue.main)
            .sink { isSessionRunning, isLivePhotoCaptureEnabled in
                // Only enable the ability to change camera if the device has
                // more than one camera.
//                self.cameraButton.isEnabled = isSessionRunning && self.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
//                self.recordButton.isEnabled = isSessionRunning && self.movieFileOutput != nil
//                self.photoButton.isEnabled = isSessionRunning
//                self.captureModeControl.isEnabled = isSessionRunning
//                self.livePhotoModeButton.isEnabled = isSessionRunning && isLivePhotoCaptureEnabled
//                self.photoQualityPrioritizationSegControl.isEnabled = isSessionRunning
            }
            .store(in: &observers)
        
        
        // Adding it this way so it can be removed the same way and readded in `AVCaptureViewModel+DeviceConfig/changeCamera(_:isUserSelection:completion:)`
        NotificationCenter.default.addObserver(forName: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device, queue: nil, using: subjectAreaDidChange(notification:))
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(subjectAreaDidChange),
//                                               name: .AVCaptureDeviceSubjectAreaDidChange,
//                                               object: videoDeviceInput.device)
        
        NotificationCenter.default.publisher(for: .AVCaptureSessionRuntimeError, object: session)
            .receive(on: sessionQueue)
            .sink(receiveValue: sessionRuntimeError(notification:))
            .store(in: &observers)
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(sessionRuntimeError),
//                                               name: .AVCaptureSessionRuntimeError,
//                                               object: session)
        
        // A session can only run when the app is full screen. It will be
        // interrupted in a multi-app layout, introduced in iOS 9, see also the
        // documentation of AVCaptureSessionInterruptionReason. Add observers to
        // handle these session interruptions and show a preview is paused
        // message. See `AVCaptureSessionWasInterruptedNotification` for other
        // interruption reasons.
        NotificationCenter.default.publisher(for: .AVCaptureSessionWasInterrupted, object: session)
            .sink(receiveValue: sessionWasInterrupted(notification:))
            .store(in: &observers)
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(sessionWasInterrupted),
//                                               name: .AVCaptureSessionWasInterrupted,
//                                               object: session)
        
        NotificationCenter.default.publisher(for: .AVCaptureSessionInterruptionEnded, object: session)
            .sink(receiveValue: sessionInterruptionEnded(notification:))
            .store(in: &observers)
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(sessionInterruptionEnded),
//                                               name: .AVCaptureSessionInterruptionEnded,
//                                               object: session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        observers.forEach { $0.cancel() }
        observers.removeAll()
    }
}

// MARK: - KVO-Related Functions

extension AVCaptureViewModel {
    // systemPreferredCameraContext is used in `observeValue`
//    private var systemPreferredCameraContext = 0
    
//    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
//        if context == &systemPreferredCameraContext {
//            guard let systemPreferredCamera = change?[.newKey] as? AVCaptureDevice else { return }
//
//            // Don't switch cameras if movie recording is in progress.
//            if let movieFileOutput = self.movieFileOutput, movieFileOutput.isRecording {
//                return
//            }
//            if self.videoDeviceInput.device == systemPreferredCamera {
//                return
//            }
//
//            self.changeCamera(systemPreferredCamera, isUserSelection: false)
//        } else {
//            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
//        }
//    }
    
    internal func subjectAreaDidChange(notification: Notification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    /// - Tag: HandleRuntimeError
    internal func sessionRuntimeError(notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
        // If media services were reset, and the last start succeeded, restart
        // the session.
        if error.code == .mediaServicesWereReset {
            if self.isSessionRunning {
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            } else {
//                DispatchQueue.main.async {
//                    self.resumeButton.isHidden = false
//                }
            }
        } else {
//            resumeButton.isHidden = false
        }
    }
    
    /// - Tag: HandleInterruption
    internal func sessionWasInterrupted(notification: Notification) {
        // In some scenarios you want to enable the user to resume the session.
        // For example, if music playback is initiated from Control Center while
        // using AVCam, then the user can let AVCam resume the session running,
        // which will stop music playback. Note that stopping music playback in
        // Control Center will not automatically resume the session. Also note
        // that it's not always possible to resume, see
        // `resumeInterruptedSession(_:)`.
        if let reasonIntegerValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
            var showResumeButton = false
            if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
                showResumeButton = true
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                // Fade-in a label to inform the user that the camera is
                // unavailable.
//                cameraUnavailableLabel.alpha = 0
//                cameraUnavailableLabel.isHidden = false
//                UIView.animate(withDuration: 0.25) {
//                    self.cameraUnavailableLabel.alpha = 1
//                }
            } else if reason == .videoDeviceNotAvailableDueToSystemPressure {
                print("Session stopped running due to shutdown system pressure level.")
            }
            if showResumeButton {
                // Fade-in a button to enable the user to try to resume the
                // session running.
//                resumeButton.alpha = 0
//                resumeButton.isHidden = false
//                UIView.animate(withDuration: 0.25) {
//                    self.resumeButton.alpha = 1
//                }
            }
        }
    }
    
    internal func sessionInterruptionEnded(notification: Notification) {
        print("Capture session interruption ended")
        
//        if !resumeButton.isHidden {
//            UIView.animate(withDuration: 0.25,
//                           animations: {
//                self.resumeButton.alpha = 0
//            }, completion: { _ in
//                self.resumeButton.isHidden = true
//            })
//        }
//        if !cameraUnavailableLabel.isHidden {
//            UIView.animate(withDuration: 0.25,
//                           animations: {
//                self.cameraUnavailableLabel.alpha = 0
//            }, completion: { _ in
//                self.cameraUnavailableLabel.isHidden = true
//            })
//        }
    }
}
