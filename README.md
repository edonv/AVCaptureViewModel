# AVCaptureViewModel

`AVCaptureViewModel` is an `ObservableObject` with exposed `@Published` properties to be used with the provided ``CameraPreview`` (SwiftUI) or ``CameraPreviewView`` (UIKit). It allows you to build a custom interface around them as part of a larger `View` or `UIViewController` (respectively) for capturing photos and videos.

It can be used to capture photos and videos to be immediately sent to the device's photo library, or you can subscribe to provided `@Published` properties to get the captures as they happen.

There is still more work to be done to provide more granular control, but it's already functional as it is.
