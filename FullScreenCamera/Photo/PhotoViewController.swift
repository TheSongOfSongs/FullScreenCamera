//
//  PhotoViewController.swift
//  FullScreenCamera
//
//  Created by Jinhyang on 2020/07/06.

import UIKit
import Photos

class PhotoViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var original: UIView!
    @IBOutlet weak var chrome: UIView!
    @IBOutlet weak var instant: UIView!
    @IBOutlet weak var transfer: UIView!
    @IBOutlet weak var sepia: UIView!
    @IBOutlet weak var tonal: UIView!
    
    var selectedImage: UIImage?
    var context = CIContext(options: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.imageView.image = selectedImage
    }
    
    func setFilter(filterName: String){
        if let selectedImage = selectedImage, let filter = CIFilter(name: filterName) {
            filter.setValue(CIImage(image: selectedImage), forKey: kCIInputImageKey)
            
            if let ciImage = filter.outputImage {
                let uiImage: UIImage = UIImage(ciImage: ciImage)
                var cgImage: CGImage? = uiImage.cgImage
                
                if cgImage == nil, let contextImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    cgImage = contextImage
                }
                
                if let cgImage = cgImage {
                    let resultImage = UIImage(cgImage: cgImage)
                    self.imageView.image = resultImage
                }
            }
        }
    }
    
    
    @IBAction func savePhoto(_ sender: UIButton) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { self.alert(title: "앨범 접근 확인", message: "앱 환경설정에서 사진 접근을 허용해주세요")
                return }
            
            OperationQueue.main.addOperation {
                guard let image = self.imageView.image else {
                    self.alert(title: "저장 실패", message: "저장할 수 없습니다")
                    return }
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { (bool, error) in
                    if bool == true {
                        self.alert(title: "저장 성공", message: "사진에서 확인해보세요!")
                    } else {
                        self.alert(title: "저장 실패", message: "저장할 수 없습니다")
                    }
                })
            }
        }
    }
    
    func alert(title: String, message: String) {
        OperationQueue.main.addOperation {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let ok = UIAlertAction(title: "확인", style: .default) { _ in
                self.dismiss(animated: true, completion: nil)
            }
            alert.addAction(ok)
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func cancel(_ sender: UIButton) {
        self.dismiss(animated: false, completion: nil)
    }
    
    
    
    // MARK: - ScrollView
    @IBAction func removeFilter(_ sender: UITapGestureRecognizer) {
        self.imageView.image = selectedImage
    }
    
    @IBAction func setFilterChrome(_ sender: UITapGestureRecognizer) {
        setFilter(filterName: "CIPhotoEffectChrome")
    }
    
    @IBAction func setInstantFilter(_ sender: UITapGestureRecognizer) {
        setFilter(filterName: "CIPhotoEffectInstant")
    }
    
    @IBAction func setTransferFilter(_ sender: UITapGestureRecognizer) {
        setFilter(filterName: "CIPhotoEffectTransfer")
    }
    
    @IBAction func setSepiaFilter(_ sender: UITapGestureRecognizer) {
        setFilter(filterName: "CISepiaTone")
    }
    
    @IBAction func setTonalFilter(_ sender: UITapGestureRecognizer) {
        setFilter(filterName: "CIPhotoEffectTonal")
    }
    
}

