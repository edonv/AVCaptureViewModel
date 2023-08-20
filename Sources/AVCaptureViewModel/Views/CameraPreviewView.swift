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
//    #warning("what to do with this and stuff at the bottom of file?")
//    public var allowGesturesOutsidePreview: Bool = false
    
//    private var observers = Set<AnyCancellable>()
    
//    public override init(frame: CGRect) {
//        super.init(frame: frame)
////        self.setUp()
//    }
//
//    public required init?(coder: NSCoder) {
//        super.init(coder: coder)
////        self.setUp()
//    }
    
//    private func setUp() {
//        videoPreviewLayer.publisher(for: \.session)
//            .compactMap { $0 }
//            .first()
//            .sink(receiveValue: addSessionObserver(_:))
//            .store(in: &observers)
//    }
    
//    private func addSessionObserver(_ session: AVCaptureSession) {
//        print("Started observing .sessionPreset")
//        session.publisher(for: \.sessionPreset)
////            .map { $0 == .photo }
//            .print()
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] _ in
//                guard let self else { return }
//                self.bounds.size = videoPreviewRect.size
//
////                self.setNeedsLayout()
////                self.layoutIfNeeded()
//            }
//            .store(in: &observers)
//    }
    
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
    
//    public override var intrinsicContentSize: CGSize {
//        videoPreviewRect.size
//    }
    
//    public override func layoutSubviews() {
//        super.layoutSubviews()
//
//        if videoPreviewRect.size != bounds.size {
//            bounds.size = videoPreviewRect.size
//        }
//    }
}

extension CameraPreviewView {
    private var videoPreviewRect: CGRect {
        let topLeading = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 0, y: 1))
        let topTrailing = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 0, y: 0))
        let bottomLeading = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 1, y: 1))
        return CGRect(origin: topLeading, size: CGSize(width: topTrailing.x - topLeading.x, height: bottomLeading.y - topLeading.y))
    }
    
//    #warning("Check that the DocC link below works")
    /// This override checks if gestures on the view should be registered by checking if they fall within the visible preview.
    ///
    /// - Important: This means that if there is empty space around the preview, touches won't register. If you want to bypass this check, set ``allowGesturesOutsidePreview`` to `true`.
//    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//        guard !allowGesturesOutsidePreview else { return true }
//        let touchLocation = gestureRecognizer.location(in: self)
////        print("videoPreviewRect:", videoPreviewRect)
//        print(videoPreviewRect.contains(touchLocation))
//        return videoPreviewRect.contains(touchLocation)
//    }
}
