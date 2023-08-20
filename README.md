# AVCaptureViewModel

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fedonv%2FAVCaptureViewModel%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/edonv/AVCaptureViewModel)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fedonv%2FAVCaptureViewModel%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/edonv/AVCaptureViewModel)

`AVCaptureViewModel` is an `ObservableObject` with exposed `@Published` properties to be used with the provided ``CameraPreview`` (SwiftUI) or ``CameraPreviewView`` (UIKit). It allows you to build a custom interface around them as part of a larger `View` or `UIViewController` (respectively) for capturing photos and videos.

It can be used to capture photos and videos to be immediately sent to the device's photo library, or you can subscribe to provided `@Published` properties to get the captures as they happen.

## Future and Next Steps

There is still more work to be done to provide more granular control, but it's already functional as it is.

Things to add:
- [ ] Some kind of subscribable publisher (likely a `CurrentValueSubject`) for publishing events (such as photo capture starting/ending, etc)
- [ ] Exposing more properties for customizability
- [ ] Fix existing issues with screen rotation

## Credit

Most of the behind-scenes-code stems directly from Apple's [AVCam tutorial](https://developer.apple.com/documentation/avfoundation/capture_setup/avcam_building_a_camera_app). I started with the current version of it (parts of which require iOS 17/Xcode 15), and I made it backwards-compatible to iOS 13. I also reworked parts of the code to work with properties of `AVCaptureViewModel`, as well as to replace `@IBAction`s and `@IBOutlets`. Additionally, I turned their `PreviewView` into `CameraPreviewView` and wrapped it with `CameraPreview`.
