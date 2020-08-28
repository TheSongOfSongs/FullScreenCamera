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
import Photos

class CameraManager: NSObject {
    
    var assetWriter: AVAssetWriter?
    
    var assetVideoWriter: AVAssetWriterInput?
    
    var assetAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    var photoOutput = AVCapturePhotoOutput()
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    
    let captureSession = AVCaptureSession()
    
    let sessionQueue = DispatchQueue(label: "session Queue")
    
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera, .builtInTrueDepthCamera],
                                                                       mediaType: .video, position: .unspecified)
    
    var completion: (UIImage) -> Void = { image in return }
    
    var captureButtonCompletion: (Bool) -> Void = { isRecording in return }
    
    var context = CIContext(options: nil)
    
    let filterManager = FilterManager.shared
    
    var isCamera: Bool = true
    
    var isWriting: Bool = false
    
    var startTime: CMTime? {
        didSet {
            isWriting = startTime == nil ? false : true
        }
    }
    
    private var _outputUrl: URL?

    var outputUrl: URL {
        get {
            if let url = _outputUrl {
                return url
            }

            _outputUrl = outputDirectory.appendingPathComponent("test.mp4")

            return _outputUrl!
        }
    }

    private var _outputDirectory: URL?

    var outputDirectory: URL {
        get {
            if let url = _outputDirectory {
                return url
            }

            _outputDirectory = getDocumentsDirectory().appendingPathComponent("recording")

            return _outputDirectory!
        }
    }
    
    
//    var videoSize = CGSize(width: 1080, height: 720) // 이후 사이즈 확인할 것!!!!!!!!!!!
    var videoSize: CGSize?
    
    func toggleCameraRecorderStatus() {
        isCamera.toggle()
    }
    
    
    
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
                self.captureSession.addOutput(self.videoDataOutput)
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
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
    
    // MARK: - record video
    func configureAssetWrtier() {
        prepareVideoFile()
        
        do {
            assetWriter = try AVAssetWriter(url: outputUrl, fileType: AVFileType.mp4)
            
            guard assetWriter != nil else { return }
            let videoSize: CGSize = self.videoSize ?? CGSize(width: 1280, height: 720)
            
            let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                                AVVideoWidthKey: videoSize.width,
                                                AVVideoHeightKey: videoSize.height,
                                                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 44100]
            ]
            
            assetVideoWriter = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
            assetVideoWriter?.expectsMediaDataInRealTime = true
            
            guard let assetVideoWriter = assetVideoWriter else { return }
            assetWriter?.add(assetVideoWriter)
            
            let adaptorSettings: [String: Any] = [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32RGBA]
            assetAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetVideoWriter, sourcePixelBufferAttributes: adaptorSettings)

        } catch {
            print("Unable to remove file at URL \(outputUrl)")
        }
    }
    
    // MARK: TODO - refactoring
    // captureOutput의 속도가 매우 빨라서 startWriting이 되기 이전에
    // startSession이 호출됨 (디버깅에선 에러X, 실행하면 에러)
    func controlRecording() {
        if isWriting {
            isWriting.toggle()
            stopRecording()
        } else {
            isWriting.toggle()
        }

        captureButtonCompletion(isWriting)
    }
    
    func startRecording() {
        assetWriter?.startWriting()
    }
    
    func stopRecording() {
        guard startTime != nil else { return }
        
        sessionQueue.async {
            self.assetWriter?.finishWriting {
                self.startTime = nil
                self.saveVideo()
            }
        }
    }
    
    func saveVideo() {
        sessionQueue.async {
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges({
                        guard let video = self.assetWriter?.outputURL else { return }
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video)
                    }, completionHandler: { (success, error) in
                        if error != nil {
                            print(error?.localizedDescription ?? "")
                        }
                    })
                }
            }
        }
    }
    
    func prepareVideoFile() {
        if FileManager.default.fileExists(atPath: outputUrl.path) {
            do {
                try FileManager.default.removeItem(at: outputUrl)
            } catch {
                print("Unable to remove file at URL \(outputUrl)")
            }
        }
        
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Unable to create directory at URL \(outputDirectory)")
            }
        }
    }
    
    func setVideoSize(size: CGSize) {
        videoSize = size
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        
        return documentsDirectory
    }
}


extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        connection.videoOrientation = .portrait // 기본 orientation; [back: 90], [front: -90]
        
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
                    let resultImage = UIImage(cgImage: cgImage)
                    image = resultImage
                }
            }
        }
        
        completion(image)
        
        if !isCamera {
            guard isWriting else { return }
            let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            recordBuffer(pixelBuffer: imageBuffer, timeStamp: timeStamp)
        }
    }
    
    func convert(ciImage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        guard let cgImage:CGImage = context.createCGImage(ciImage, from: ciImage.extent) else { return UIImage() }
        let image: UIImage = UIImage(cgImage: cgImage)
        
        return image
    }
    
    func recordBuffer(pixelBuffer: CVPixelBuffer, timeStamp: CMTime) {
        if startTime == nil {
            startRecording()
            
            startTime = timeStamp
            assetWriter?.startSession(atSourceTime: timeStamp)
        }
        
        assetAdaptor?.append(pixelBuffer, withPresentationTime: timeStamp)
    }
}
