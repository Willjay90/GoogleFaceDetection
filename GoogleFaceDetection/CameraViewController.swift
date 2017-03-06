//
//  ViewController.swift
//  GoogleFaceDetection
//
//  Created by Wei Chieh Tseng on 03/03/2017.
//  Copyright © 2017 Willjay. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import GoogleMobileVision



class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var placeholder: UIView!
    @IBOutlet weak var overlay: UIView!
    @IBOutlet weak var cameraSwitch: UISwitch! {
        didSet {
            devicePosition = self.cameraSwitch.isOn ? .front : .back
        }
    }
    
    var videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    
    var faceDetector: GMVDetector!
    
    var lastKnownDeviceOrientation: UIDeviceOrientation = .unknown
    
    var captureDevice: AVCaptureDevice!
    var session: AVCaptureSession!
    var videoDataOutput: AVCaptureVideoDataOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var devicePosition: AVCaptureDevicePosition!

    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up default camera settings.
        self.cameraSwitch.isOn = true
        self.session = AVCaptureSession()
        self.session.sessionPreset = AVCaptureSessionPresetMedium
        self.updateCameraSelection()
        
        // Setup video processing pipeline.
        self.setupVideoProcessing()
        
        // Setup camera preview.
        self.setupCameraPreview()

        // Initialize the face detector.
        let detectorOptions: [AnyHashable: Any] = [GMVDetectorFaceMinSize: 0.3,
                               GMVDetectorFaceTrackingEnabled: true,
                               GMVDetectorFaceLandmarkType: GMVDetectorFaceLandmark.all.rawValue]
        self.faceDetector = GMVDetector(ofType: GMVDetectorTypeFace, options: detectorOptions)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.layer.bounds
        self.previewLayer.position = CGPoint(x: self.previewLayer.frame.midX, y: self.previewLayer.frame.midY)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        self.session.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        self.session.stopRunning()
    }
    
    
    override func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        if self.previewLayer != nil {
            if (toInterfaceOrientation == .portrait) {
                self.previewLayer.connection.videoOrientation = .portrait
            } else if (toInterfaceOrientation == .portraitUpsideDown) {
                self.previewLayer.connection.videoOrientation = .portraitUpsideDown
            } else if (toInterfaceOrientation == .landscapeLeft) {
                self.previewLayer.connection.videoOrientation = .landscapeLeft
            } else if (toInterfaceOrientation == .landscapeRight) {
                self.previewLayer.connection.videoOrientation = .landscapeRight
            }

        }
    }

    @IBAction func cameraDeviceChanged(_ sender: UISwitch) {
        updateCameraSelection()
    }
    
    func updateCameraSelection() {
        self.session.beginConfiguration()
        // Remove old inputs
        let oldInputs = self.session.inputs as! [AVCaptureInput]
        for oldInput in oldInputs {
            self.session.removeInput(oldInput)
        }
        
        let desiredPosition: AVCaptureDevicePosition = cameraSwitch.isOn ? .front : .back
        captureDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: desiredPosition)
        
        do {
            let input = try AVCaptureDeviceInput(device: self.captureDevice)
            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.session.commitConfiguration()
            }
        }
            
        catch {
            // Failed, restore old inputs
            for oldInput in oldInputs {
                self.session.addInput(oldInput)
            }
            self.session.commitConfiguration()
        }
        
        
    }

    
    func setupVideoProcessing() {
        self.videoDataOutput = AVCaptureVideoDataOutput()
        let rgbOutputSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)]
        self.videoDataOutput.videoSettings = rgbOutputSettings
        
        if !self.session.canAddOutput(videoDataOutput) {
            cleanupVideoProcessing()
            print("Failed to setup video output")
            return
        }
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        self.session.addOutput(videoDataOutput)
        
    }
    
    func cleanupVideoProcessing() {
        if (videoDataOutput != nil) {
            self.session.removeOutput(videoDataOutput)
        }
        self.videoDataOutput = nil
    }
    
    func setupCameraPreview() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.previewLayer.backgroundColor = UIColor.white.cgColor
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect
        let rootLayer = self.placeholder.layer
        rootLayer.masksToBounds = true
        self.previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(self.previewLayer)
    }
     
    private func scaledRect(_ rect: CGRect, xScale xscale: CGFloat, yScale yscale: CGFloat, offset: CGPoint) -> CGRect {
        var resultRect = CGRect(x: CGFloat(rect.origin.x * xscale), y: CGFloat(rect.origin.y * yscale), width: CGFloat(rect.size.width * xscale), height: CGFloat(rect.size.height * yscale))
        resultRect = resultRect.offsetBy(dx: CGFloat(offset.x), dy: CGFloat(offset.y))
        return resultRect
    }
    
    private func scalePoint(_ point: CGPoint, xScale xscale: CGFloat, yScale yscale: CGFloat, offset: CGPoint) -> CGPoint {
        let resultPoint = CGPoint(x: point.x * xscale + offset.x, y: point.y * yscale + offset.y)
        return resultPoint
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        guard let image = GMVUtility.sampleBufferTo32RGBA(sampleBuffer) else {
            print("No Image 😂")
            return
        }
        
        // Establish the image orientation.
        let deviceOrientation = UIDevice.current.orientation
        let orientation: GMVImageOrientation = GMVUtility.imageOrientation(from: deviceOrientation, with: devicePosition, defaultDeviceOrientation: self.lastKnownDeviceOrientation)
        let options = [GMVDetectorImageOrientation: orientation.rawValue] // rawValue
        
        // Detect features using GMVDetector.
        guard let faces = self.faceDetector.features(in: image, options: options) as? [GMVFaceFeature] else {
            print("No Faces 😂")
            return
        }
        print("Detected faces: \(faces.count)")

        // The video frames captured by the camera are a different size than the video preview.
        // Calculates the scale factors and offset to properly display the features.
        let fdesc = CMSampleBufferGetFormatDescription(sampleBuffer)
        let clap = CMVideoFormatDescriptionGetCleanAperture(fdesc!, false)
        let parentFrameSize = self.previewLayer.frame.size
        
        // Assume AVLayerVideoGravityResizeAspect
        let cameraRatio = clap.size.height / clap.size.width
        let viewRatio = parentFrameSize.width / parentFrameSize.height
        var xScale: CGFloat = 1, yScale: CGFloat = 1
        var videoBox = CGRect.zero

        if (viewRatio > cameraRatio) {
            videoBox.size.width = parentFrameSize.height * clap.size.width / clap.size.height
            videoBox.size.height = parentFrameSize.height
            videoBox.origin.x = (parentFrameSize.width - videoBox.size.width) / 2
            videoBox.origin.y = (videoBox.size.height - parentFrameSize.height) / 2
            
            xScale = videoBox.size.width / clap.size.width
            yScale = videoBox.size.height / clap.size.height
        } else {
            videoBox.size.width = parentFrameSize.width
            videoBox.size.height = clap.size.width * (parentFrameSize.width / clap.size.height);
            videoBox.origin.x = (videoBox.size.width - parentFrameSize.width) / 2
            videoBox.origin.y = (parentFrameSize.height - videoBox.size.height) / 2
            
            xScale = videoBox.size.width / clap.size.height
            yScale = videoBox.size.height / clap.size.width
        }

        DispatchQueue.main.sync {
            // Remove previously added feature views.
            for featureView in self.overlay.subviews {
                featureView.removeFromSuperview()
            }
            
            // Display detected features in overlay.
            for face in faces {
                let faceRect = self.scaledRect(face.bounds, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                DrawingUtility.addRectangle(faceRect, to: overlay, with: .red)
            
                // Mouth
                
                if face.hasBottomMouthPosition {
                    let point = self.scalePoint(face.bottomMouthPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlay, with: .green, withRadius: 5)
                }
                if face.hasMouthPosition {
                    let point = self.scalePoint(face.mouthPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlay, with: .green, withRadius: 10)
                }
                if face.hasRightMouthPosition {
                    let point = self.scalePoint(face.rightMouthPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlay, with: .green, withRadius: 5)
                }
                if face.hasLeftMouthPosition {
                    let point = self.scalePoint(face.leftMouthPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlay, with: .green, withRadius: 5)
                }
                
                // nose
                if face.hasNoseBasePosition {
                    let point = self.scalePoint(face.noseBasePosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: self.overlay, with: .darkGray, withRadius: 10)
                }
                
                // eyes
                if face.hasLeftEyePosition {
                    let point = self.scalePoint(face.leftEyePosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: self.overlay, with: .blue, withRadius: 10)
                }
                
                if face.hasRightEyePosition {
                    let point = self.scalePoint(face.rightEyePosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: self.overlay, with: .blue, withRadius: 10)
                }
                
                // ears
                if face.hasLeftEarPosition {
                    let point = self.scalePoint(face.leftEarPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: self.overlay, with: .purple, withRadius: 10)
                }
                
                if face.hasRightEarPosition {
                    let point = self.scalePoint(face.rightEarPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: self.overlay, with: .purple, withRadius: 10)
                }
                
                // cheeks
                if face.hasLeftCheekPosition {
                    let point = self.scalePoint(face.leftCheekPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: self.overlay, with: .magenta, withRadius: 10)
                }
                
                if face.hasRightCheekPosition {
                    let point = self.scalePoint(face.rightCheekPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: self.overlay, with: .magenta, withRadius: 10)
                }
                
                // Tracking Id.
                if face.hasTrackingID {
                    let point = self.scalePoint(face.bounds.origin, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    let label = UILabel(frame: CGRect(x: CGFloat(point.x), y: CGFloat(point.y), width: CGFloat(100), height: CGFloat(20)))
                    label.text = "id: \(UInt(face.trackingID))"
                    self.overlay.addSubview(label)
                }
                
            }
        }

    }

}

