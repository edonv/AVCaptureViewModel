//
//  CameraPreview.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import SwiftUI
import AVFoundation

/// A SwiftUI `UIViewRepresentable` wrapper of ``CameraPreviewView``.
/// > Important: Even when there is empty space around the preview, it's part of the view. It's transparent, so you can set a background color, but it will still register taps and gestures on the empty space.
public struct CameraPreview: UIViewRepresentable {
    /// The view preview `CALayer` from ``CameraPreviewView/videoPreviewLayer``, that is shared with ``AVCaptureViewModel/AVCaptureViewModel/videoPreviewLayer``.
    @Binding public var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    /// The preview layer's capture session from ``AVCaptureViewModel/AVCaptureViewModel/session`` that is passed to ``CameraPreviewView``.
    public var session: AVCaptureSession?
    
    public init(videoPreviewLayer: Binding<AVCaptureVideoPreviewLayer?>, session: AVCaptureSession?) {
        self._videoPreviewLayer = videoPreviewLayer
        self.session = session
    }
        
    public func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView(frame: .zero)
        videoPreviewLayer = view.videoPreviewLayer
//        view.videoPreviewLayer.needsDisplayOnBoundsChange = true
        view.session = session
        return view
    }
    
    public func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        
    }
}

extension CameraPreview {
    private var videoPreviewRect: CGRect? {
        guard let videoPreviewLayer else { return nil }
        let topLeading = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 0, y: 1))
        let topTrailing = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 0, y: 0))
        let bottomLeading = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 1, y: 1))
        return CGRect(origin: topLeading, size: CGSize(width: topTrailing.x - topLeading.x, height: bottomLeading.y - topLeading.y))
    }
    
    private var videoPreviewPath: Path? {
        guard let videoPreviewRect else { return nil }
        return Path(videoPreviewRect)
    }
    
//    @ViewBuilder
//    public func limitGesturesToPreviewArea() -> some View {
//        if let videoPreviewPath {
//            self
//                .contentShape(videoPreviewPath)
//        } else {
//            self
//        }
//    }
}
