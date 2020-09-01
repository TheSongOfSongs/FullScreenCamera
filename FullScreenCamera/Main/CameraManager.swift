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
    
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera,
                                                                                     .builtInTrueDepthCamera],
                                                                       mediaType: .video,
                                                                       position: .unspecified)
    
    let captureSession = AVCaptureSession()
    
    let sessionQueue = DispatchQueue(label: "session Queue")
    
    let audioQueue = DispatchQueue(label: "audio Queue")
    
    var assetWriter: AVAssetWriter?
    
    var assetVideoWriter: AVAssetWriterInput?
    
    var assetAudioWriter: AVAssetWriterInput?
    
    var assetAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    var photoOutput = AVCapturePhotoOutput()
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    
    var audioDataOutput = AVCaptureAudioDataOutput()
    
    
    var completion: (UIImage) -> Void = { image in return }
    
    var captureButtonCompletion: (Bool) -> Void = { isRecording in return }
    
    let filterManager = FilterManager.shared
    
    var context = CIContext(options: nil)
    
    var isCamera: Bool = true
    
    var isWriting: Bool = false
    
    var startTime: CMTime? {
        didSet {
            isWriting = startTime == nil ? false : true
        }
    }
    
    var outputUrl: URL?

    var outputDirectory: URL?
    
    var videoSize: CGSize?
    
    func toggleCameraRecorderStatus() {
        isCamera.toggle()
    }
    
    
    // MARK: - control session
    func setupSession() {
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            self.setupVideoSession()
            self.setupAudioSession()
            
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
    
    
    // MARK: - set up session
    func setupVideoSession() {
        do {
            guard let camera = self.videoDeviceDiscoverySession.devices.first else { return }
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            
            if self.captureSession.canAddInput(videoDeviceInput) {
                self.captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                if self.captureSession.canAddOutput(self.photoOutput) {
                    self.photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey:AVVideoCodecType.jpeg])], completionHandler: nil)
                    self.captureSession.addOutput(self.photoOutput)
                    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                    self.captureSession.addOutput(self.videoDataOutput)
                }
            }
        } catch {
            return
        }
    }
    
    func setupAudioSession() {
        do {
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if self.captureSession.canAddInput(audioDeviceInput) {
                self.captureSession.addInput(audioDeviceInput)
            }
            
            if self.captureSession.canAddOutput(self.audioDataOutput) {
                self.audioDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                self.audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4)
                self.captureSession.addOutput(self.audioDataOutput)
            }
        } catch {
            return
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
                    self.captureSession.commitConfiguration()
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
            assetWriter = try AVAssetWriter(url: URL.outputUrl, fileType: AVFileType.mp4)
            
            configureAssetVideoWriter()
            configureAssetAudioWriter()
            
            if let assetVideoWriter = assetVideoWriter {
                let adaptorSettings: [String: Any] = [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32RGBA]
                assetAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetVideoWriter, sourcePixelBufferAttributes: adaptorSettings)
            }
            
        } catch {
            print("Unable to remove file at URL \(String(describing: outputUrl))")
        }
    }
    
    func configureAssetVideoWriter() {
        let videoSize = self.videoSize ?? CGSize(width: 1920, height: 1080)
        
        let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                            AVVideoWidthKey: videoSize.height,
                                            AVVideoHeightKey: videoSize.width,
                                            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: videoSize.width * videoSize.height]
        ]
        
        assetVideoWriter = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        assetVideoWriter?.expectsMediaDataInRealTime = true
        
        assetVideoWriter = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        assetVideoWriter?.expectsMediaDataInRealTime = true
        
        guard let assetVideoWriter = assetVideoWriter else { return }
        assetWriter?.add(assetVideoWriter)
    }
    
    func configureAssetAudioWriter() {
        let audioSettings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                            AVNumberOfChannelsKey: 2,
                                            AVSampleRateKey: 44100,
                                            AVEncoderBitRateKey: 192000]
        
        assetAudioWriter = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        assetAudioWriter?.expectsMediaDataInRealTime = true
        
        guard let assetAudioWriter = assetAudioWriter else { return }
        assetWriter?.add(assetAudioWriter)
    }
    
    
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
        let ouputUrl = URL.outputUrl
        let outputDirectory = URL.outputDirectory
        
        if FileManager.default.fileExists(atPath: ouputUrl.path) {
            do {
                try FileManager.default.removeItem(at: ouputUrl)
            } catch {
                print("Unable to remove file at URL \(ouputUrl)")
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
}


extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if output == videoDataOutput {
            writeVideoBuffer(output: output, sampleBuffer: sampleBuffer, connection: connection)
        } else {
            writeAudioBuffer(sampleBuffer: sampleBuffer)
        }
    }
    
    func writeVideoBuffer(output: AVCaptureOutput, sampleBuffer: CMSampleBuffer, connection: AVCaptureConnection) {
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait // 기본 orientation; [back: 90], [front: -90]
        }
        
        guard let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let cgImage = getFilterImage(imageBuffer: imageBuffer)
        let uiImage = UIImage(cgImage: cgImage!)
        let imageSize = uiImage.size
        
        if videoSize == nil { videoSize = imageSize }
        
        completion(uiImage)
        
        if !isCamera {
            guard isWriting else { return }
            
            if output == videoDataOutput, let cgImage = cgImage, let pixelBuffer = cgImage.convertToCVPixelBuffer(size: imageSize) {
                let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                appendBuffer(pixelBuffer: pixelBuffer, timeStamp: timeStamp)
            }
        }
    }
    
    func writeAudioBuffer(sampleBuffer: CMSampleBuffer) {
        guard isWriting else { return }
        assetAudioWriter?.append(sampleBuffer)
    }
    
    func getFilterImage(imageBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage: CIImage = CIImage(cvPixelBuffer: imageBuffer)
        var cgImage: CGImage?
        
        if let filterName = filterManager.currentFilter, let filter = CIFilter(name: filterName) {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            
            if let ciImage = filter.outputImage {
                cgImage = ciImage.convertToCGImage()
                return cgImage
            }
        }
        
        return ciImage.convertToCGImage()
    }
    
    
    func appendBuffer(pixelBuffer: CVPixelBuffer, timeStamp: CMTime) {
        if startTime == nil {
            
            startRecording()
            startTime = timeStamp
            assetWriter?.startSession(atSourceTime: timeStamp)
        }
        
        assetAdaptor?.append(pixelBuffer, withPresentationTime: timeStamp)
    }
}

extension URL {
    static let outputDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("recording")
    
    static let outputUrl = outputDirectory.appendingPathComponent("test.mp4")
}


/** convert image type **/

extension CIImage {
    func convertToCGImage() -> CGImage? {
        let context = CIContext(options: nil)
        return context.createCGImage(self, from: self.extent)
    }
}


extension CGImage {
    func convertToCVPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attributes, &pixelBuffer)
        guard (status == kCVReturnSuccess) else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(data: pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.scaleBy(x: 1.0, y: 1.0)
        context?.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}
