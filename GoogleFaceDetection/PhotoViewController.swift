//
//  PhotoViewController.swift
//  GoogleFaceDetection
//
//  Created by Wei Chieh Tseng on 06/03/2017.
//  Copyright © 2017 Willjay. All rights reserved.
//

import UIKit
import GoogleMobileVision

class PhotoViewController: UIViewController {

    @IBOutlet weak var faceImageView: UIImageView!
    @IBOutlet weak var overlay: UIView!

    var faceDetector: GMVDetector!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Instantiate a face detector that searches for all landmarks and classifications.
        let options: [AnyHashable: Any] =
            [GMVDetectorFaceLandmarkType: GMVDetectorFaceLandmark.all.rawValue,
             GMVDetectorFaceClassificationType: GMVDetectorFaceClassification.all.rawValue,
             GMVDetectorFaceMinSize: 0.3,
             GMVDetectorFaceTrackingEnabled: false
            ]
        faceDetector = GMVDetector(ofType: GMVDetectorTypeFace, options: options)
        
    }

    @IBAction func faceRecognitionClicked(_ sender: UIButton) {
        for annotationView in self.overlay.subviews {
            annotationView.removeFromSuperview()
        }
        
        // Invoke features detection.
        let faces = self.faceDetector.features(in: self.faceImageView.image, options: nil) as? [GMVFaceFeature]
        print("faces count: \(faces?.count)")
        
        // Compute image offset.
        let translate = CGAffineTransform.identity.translatedBy(x: (self.view.frame.size.width - (self.faceImageView.image?.size.width)!) / 2, y: (self.view.frame.size.height - (self.faceImageView.image?.size.height)!) / 2)
        
        for face in faces! {
            // face
            let rect = face.bounds
            DrawingUtility.addRectangle(rect.applying(translate), to: self.overlay, with: .red)
            
            // mouth
            if face.hasMouthPosition {
                let point = face.bottomMouthPosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .green, withRadius: 2)
            }
            if face.hasMouthPosition {
                let point = face.mouthPosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .green, withRadius: 2)
            }
            if face.hasRightMouthPosition {
                let point = face.rightMouthPosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .green, withRadius: 2)
            }
            if face.hasLeftMouthPosition {
                let point = face.leftMouthPosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .green, withRadius: 2)
            }
            
            // nose
            if face.hasNoseBasePosition {
                let point = face.noseBasePosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .darkGray, withRadius: 4)
            }
            
            // eyes
            if face.hasLeftEyePosition {
                let point = face.leftEyePosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .blue, withRadius: 4)
            }
            
            if face.hasRightEyePosition {
                let point = face.rightEyePosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .blue, withRadius: 4)
            }
        
            // ears
            if face.hasLeftEarPosition {
                let point = face.leftEarPosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .purple, withRadius: 4)
            }
            
            if face.hasRightEarPosition {
                let point = face.rightEarPosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .purple, withRadius: 4)
            }
            
            // cheeks
            if face.hasLeftCheekPosition {
                let point = face.leftCheekPosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .magenta, withRadius: 4)
            }
            
            if face.hasRightCheekPosition {
                let point = face.rightCheekPosition.applying(translate)
                DrawingUtility.addCircle(at: point, to: self.overlay, with: .magenta, withRadius: 4)
            }
            
            // smile
            if face.hasSmilingProbability && face.smilingProbability > 0.4 {
                let text = String(format: "smiling %0.2f", face.smilingProbability)
                let rect = CGRect(x: face.bounds.minX, y: face.bounds.maxY + 10, width: self.overlay.frame.size.width, height: 30).applying(translate)
                DrawingUtility.addTextLabel(text, at: rect, to: self.overlay, with: .green)
            }
        }
        
        
        
    }

}
