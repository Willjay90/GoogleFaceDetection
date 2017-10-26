# GoogleFaceDetection
![ios10+](https://img.shields.io/badge/ios-10%2B-blue.svg)
![swift4+](https://img.shields.io/badge/swift-4%2B-orange.svg)

In iOS, to detect faces in a picture, you can use either [CIDetector](https://developer.apple.com/reference/coreimage/cidetector) (Apple)
or [Mobile Vision](https://developers.google.com/vision/face-detection-concepts) (Google)

In my point of view, Google Mobile Vision provide better performance.

Getting `GoogleMobileVision` with [CocoaPods](https://cocoapods.org/)
```pod
# platform :ios, ’10.0’
use_frameworks!

target 'GoogleFaceDetection' do
  pod 'GoogleMobileVision/FaceDetector'
end
```
In Terminal, get to the project directory and run `pod install` 

---
In this project, there are two modes.

### Single Image Detection && Real Time Camera Image Detection

<img src="https://github.com/Weijay/GoogleFaceDetection/blob/master/resources/PhotoMode.PNG" width="270" height="480" /> <img src="https://github.com/Weijay/GoogleFaceDetection/blob/master/resources/CameraMode.png" width="270" height="480" />


