//
//  AVCaptureViewModel+Readiness.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import Foundation
import AVFoundation

// MARK: Readiness Coordinator

//@available(iOS 17.0, *)
//extension AVCaptureViewModel: AVCapturePhotoOutputReadinessCoordinatorDelegate {
//    func readinessCoordinator(_ coordinator: AVCapturePhotoOutputReadinessCoordinator, captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness) {
//        // Enable user interaction for the shutter button only when the output
//        // is ready to capture.
////        self.photoButton.isUserInteractionEnabled = (captureReadiness == .ready) ? true : false
//
//        // Note: You can customize the shutter button's appearance based on
//        // `captureReadiness`.
//    }
//
//    private func createDeviceRotationCoordinator() {
//        videoDeviceRotationCoordinator = AVCaptureDevice.RotationCoordinator(device: videoDeviceInput.device, previewLayer: previewView.videoPreviewLayer)
//        previewView.videoPreviewLayer.connection?.videoRotationAngle = videoDeviceRotationCoordinator.videoRotationAngleForHorizonLevelPreview
//
//        videoDeviceRotationCoordinator.publisher(for: \.videoRotationAngleForHorizonLevelPreview, options: .new)
//            .sink { videoRotationAngleForHorizonLevelPreview in
//                self.previewView.videoPreviewLayer.connection?.videoRotationAngle = videoRotationAngleForHorizonLevelPreview
//            }
//            .store(in: &observers)
//    }
//}
