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
    
    var assetAudioWriter: AVAssetWriterInput?
    
    var assetAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    var photoOutput = AVCapturePhotoOutput()
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    
    var audioOutput = AVCaptureAudioDataOutput()
    
    let captureSession = AVCaptureSession()
    
    let sessionQueue = DispatchQueue(label: "session Queue")
    
    let audioQueue = DispatchQueue(label: "audio Queue")
    
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera,
                                                                                     .builtInTrueDepthCamera],
                                                                       mediaType: .video,
                                                                       position: .unspecified)
    
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
            
            self.setupCameraSession()
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
    func setupCameraSession() {
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
            
            if self.captureSession.canAddOutput(self.audioOutput) {
                self.audioOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                self.audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4)
                self.captureSession.addOutput(self.audioOutput)
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
            assetWriter = try AVAssetWriter(url: outputUrl.getUrl(), fileType: AVFileType.mp4)
            
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
        let ouputUrl = self.outputUrl.getUrl()
        let outputDirectory = self.outputDirectory.getDirectory()
        let outputDirectory2 = URL.directory
        
        
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
        completion(getFilterImage(imageBuffer: imageBuffer))
        
        if !isCamera {
            guard isWriting else { return }
            let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            if output == videoDataOutput {
                appendBuffer(pixelBuffer: imageBuffer, timeStamp: timeStamp)
            }
        }
    }
    
    func writeAudioBuffer(sampleBuffer: CMSampleBuffer) {
        guard isWriting else { return }
        assetAudioWriter?.append(sampleBuffer)
    }
    
    func getFilterImage(imageBuffer: CVPixelBuffer) -> UIImage {
        
        let ciImage: CIImage = CIImage(cvPixelBuffer: imageBuffer)
        var resultImage: UIImage = self.convert(ciImage: ciImage)
        
        if videoSize == nil { videoSize = resultImage.size }
        
        if let filterName = filterManager.currentFilter, let filter = CIFilter(name: filterName) {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            
            if let ciImage = filter.outputImage {
                let uiImage: UIImage = UIImage(ciImage: ciImage)
                var cgImage: CGImage? = uiImage.cgImage
                
                if cgImage == nil, let contextImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    cgImage = contextImage
                }
                
                if let cgImage = cgImage {
                    let image = UIImage(cgImage: cgImage)
                    resultImage = image
                }
            }
        }
        
        return resultImage
    }
    
    
    func convert(ciImage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        guard let cgImage:CGImage = context.createCGImage(ciImage, from: ciImage.extent) else { return UIImage() }
        let image: UIImage = UIImage(cgImage: cgImage)
        
        return image
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


extension Optional where Wrapped == URL {
    func getUrl() -> URL {
        return self ?? getDirectory().appendingPathComponent("test.mp4")
    }
    
    func getDirectory() -> URL {
        return self ?? getDocumentsDirectory().appendingPathComponent("recording")
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        
        return documentsDirectory
    }
}

extension URL ㅌ{
    static let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("recording")
    
}
