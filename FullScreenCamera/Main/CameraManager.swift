//
//  Camera.swift
//  FullScreenCamera
//
//  Created by Jin on 2020/08/20.
//  Copyright © 2020 com.jinhyang. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation

class CameraManager: NSObject {
    
    var videoDeviceInput: AVCaptureDeviceInput!
    var photoOutput = AVCapturePhotoOutput()
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    let captureSession = AVCaptureSession()
    let sessionQueue = DispatchQueue(label: "session Queue")
    
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    var completion: (UIImage) -> Void = { image in return }
    var context = CIContext(options: nil)
    let filterManager = FilterManager.shared
    
    // MARK: - control session
    
    func setupSession() {
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            
            guard let camera = self.videoDeviceDiscoverySession.devices.first else {
                self.captureSession.commitConfiguration()
                return
            }
            
            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
                
                if self.captureSession.canAddInput(videoDeviceInput) {
                    self.captureSession.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    self.captureSession.commitConfiguration()
                    return
                }
            } catch {
                self.captureSession.commitConfiguration()
                return
            }
            
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey:AVVideoCodecType.jpeg])], completionHandler: nil)
                self.captureSession.addOutput(self.photoOutput)
                
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                self.videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
                self.captureSession.addOutput(self.videoDataOutput)
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
//    func toggleCameraVideo(isCamera: Bool) {
//        sessionQueue.async {
//            self.captureSession.beginConfiguration()
//
//            if isCamera {
//
//            } else {
//
//
//            }
//
//        }
//    }
    
    func startSession(){
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession(){
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    // MARK: - switchCamera
    
    func isSwitchingCamera() -> Bool {
        var successSwitching: Bool = false
        guard videoDeviceDiscoverySession.devices.count > 1 else { return successSwitching }
        
        let currentVideoDevice = self.videoDeviceInput.device
        let currentPosition = currentVideoDevice.position
        let isFront = currentPosition == .front
        let preferredPosition: AVCaptureDevice.Position = isFront ? .back : .front
        let devices = self.videoDeviceDiscoverySession.devices
        let newVideoDevice: AVCaptureDevice? = devices.first(where: { device in
            return preferredPosition == device.position
        })
        
        if let newDevice = newVideoDevice {
            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: newDevice)
                
                self.captureSession.beginConfiguration()
                self.captureSession.removeInput(self.videoDeviceInput)
                
                if self.captureSession.canAddInput(videoDeviceInput) {
                    self.captureSession.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    self.captureSession.addInput(self.videoDeviceInput)
                }
                
                self.captureSession.commitConfiguration()
                successSwitching = true
                
            } catch let error {
                print("error occured while creating device input: \(error.localizedDescription)")
            }
        }
        
        return successSwitching
    }
    
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage: CIImage = CIImage(cvPixelBuffer: imageBuffer)
        var image: UIImage = self.convert(ciImage: ciImage)

        if let filterName = filterManager.currentFilter, let filter = CIFilter(name: filterName) {
            filter.setValue(ciImage, forKey: kCIInputImageKey)

            if let ciImage = filter.outputImage {
                let uiImage: UIImage = UIImage(ciImage: ciImage)
                var cgImage: CGImage? = uiImage.cgImage

                if cgImage == nil, let contextImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    cgImage = contextImage
                }

                if let cgImage = cgImage {
                    let resultImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
                    image = resultImage
                }
            }
        }
        completion(image)
    }
    
    func convert(ciImage:CIImage) -> UIImage
    {
        let context:CIContext = CIContext.init(options: nil)
        guard let cgImage:CGImage = context.createCGImage(ciImage, from: ciImage.extent) else { return UIImage() }
        let image:UIImage = UIImage(cgImage: cgImage, scale: .init(), orientation: .right)

        return image
    }
}
