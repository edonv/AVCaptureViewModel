//
//  CameraPreviewView.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import UIKit
import AVFoundation
import Combine

/// An encapsulated view containing the [`AVCaptureVideoPreviewLayer`](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer).
/// > Important: Even when there is empty space around the preview, it's part of the view. It's transparent, so you can set a background color (``backgroundColor``) or place other views behind it, but it will still register taps and gestures on the empty space.
public class CameraPreviewView: UIView {
    public override var backgroundColor: UIColor? {
        get {
            guard let color = videoPreviewLayer.backgroundColor else { return nil }
            return UIColor(cgColor: color)
        } set {
            videoPreviewLayer.backgroundColor = newValue?.cgColor
        }
    }
    
    /// The view preview `CALayer`.
    public var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check CameraPreviewView.layerClass implementation.")
        }
        return layer
    }
    
    /// The preview layer's capture session that is created by the ``AVCaptureViewModel/AVCaptureViewModel``.
    public var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        } set {
            videoPreviewLayer.session = newValue
        }
    }
    
    public override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
