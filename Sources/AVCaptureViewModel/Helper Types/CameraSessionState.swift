//
//  CameraSessionState.swift
//  
//
//  Created by Edon Valdman on 8/18/23.
//

import Foundation
import AVFoundation

// TODO: More states?

enum CameraSessionState {
    case awaitingSetUp
    
    case sessionRuntimeError(error: AVError)
    // unresumable means camera unavailable
    case sessionWasInterrupted(isResumable: Bool, reason: AVCaptureSession.InterruptionReason)
    case sessionIsUnableToResume
    case sessionInterruptionEnded
    
    case captureModeStartedChanging(toMode: AVCaptureViewModel.CaptureMode)
    case captureModeFinishedChanging(toMode: AVCaptureViewModel.CaptureMode)
    
    case cameraStartedChanging
    case cameraFinishedChanging
    
    case capturedPhoto(livePhoto: Bool)
    case livePhotosCaptureFinished
    
    case movieRecordingTriggered
    case movieRecordingStarted
    case movieRecordingFinished
    
    case sessionRunningStateChanged(to: Bool)
}
