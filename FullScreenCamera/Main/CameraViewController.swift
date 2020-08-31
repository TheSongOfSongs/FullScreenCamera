import UIKit
import AVFoundation
import Photos
import CoreImage

class CameraViewController: UIViewController {
    
    let cameraManager = CameraManager()
    
    let filterManager = FilterManager.shared
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    
    var recordOutput = AVCaptureMovieFileOutput()
    
    private lazy var filterView: UIView = {
        let monitorViewSize = self.monitorView.frame.size
        let frame = CGRect(x: 0, y: monitorViewSize.height, width: monitorViewSize.width, height: self.view.frame.size.height - monitorViewSize.height)
        
        let filterView = FilterCollection(frame: frame)
        return filterView
    }()
    
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
        [.builtInDualCamera, .builtInWideAngleCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    var cameraRecorderStatus: CameraRecorder = .camera {
        didSet {
            if cameraRecorderStatus.isCamera {
                captureButton.backgroundColor = .white
            } else {
                captureButton.backgroundColor = .red
                cameraManager.configureAssetWrtier()
            }
        }
    }
    
    enum CameraRecorder: Int {
        case camera
        case recorder
        
        var isCamera: Bool {
            switch self {
            case .camera:
                return true
            default:
                return false
            }
        }
        
        mutating func toggle() {
            switch self {
            case .camera:
                self = .recorder
            default:
                self = .camera
            }
        }
    }
    
    @IBOutlet weak var switchCameraRecorder: UIButton!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var blurBGView: UIVisualEffectView!
    @IBOutlet weak var switchButton: UIButton!
    @IBOutlet weak var recentPhoto: UIButton!
    @IBOutlet weak var cameraToggle: UIButton!
    @IBOutlet weak var monitorView: UIImageView!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.cameraManager.setupSession()
        self.cameraManager.startSession()
        
        setupUI()
    }
    
    func setupUI() {
        captureButton.layer.cornerRadius = 10
        captureButton.layer.masksToBounds = true
        captureButton.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        captureButton.layer.borderWidth = 1
        
        captureButton.layer.cornerRadius = captureButton.bounds.height/2
        captureButton.layer.masksToBounds = true
        
        blurBGView.layer.cornerRadius = blurBGView.bounds.height/2
        blurBGView.layer.masksToBounds = true
        
        cameraManager.completion = { image in
            DispatchQueue.main.async {
                self.monitorView.image = image
            }
        }
        
        cameraManager.captureButtonCompletion = { isRecording in
            DispatchQueue.main.async {
                self.captureButton.backgroundColor = isRecording ? .orange : .red
            }
        }
    }
    
    func convert(ciImage:CIImage) -> UIImage
    {
        let context:CIContext = CIContext.init(options: nil)
        guard let cgImage:CGImage = context.createCGImage(ciImage, from: ciImage.extent) else { return UIImage() }
        let image: UIImage = UIImage(cgImage: cgImage)
        
        return image
    }
    
    
    // MARK: - show filter
    @IBAction func showFilter(_ sender: UIButton) {
        self.view.addSubview(filterView)
    }
    
    @IBAction func hideFilter(_ sender: UITapGestureRecognizer) {
        filterView.removeFromSuperview()
    }
    
    
    // MARK: - show Recent Photo
    @IBAction func showPhoto(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .fullScreen
        self.present(picker, animated: false, completion: nil)
    }
    
    
    // MARK: - switch Camera
    @IBAction func switchCamera(sender: Any) {
        if cameraManager.isSwitchingCamera() {
            self.updateSwitchCameraIcon()
        }
    }
    
    func updateSwitchCameraIcon() {
        let position = cameraManager.videoDeviceInput.device.position
        
        switch position {
        case .front:
            let image = #imageLiteral(resourceName: "ic_camera_front")
            switchButton.setImage(image, for: .normal)
        case .back:
            let image = #imageLiteral(resourceName: "ic_camera_rear")
            switchButton.setImage(image, for: .normal)
        default:
            break
        }
    }
    
    // MARK: - switch input between photo and video
    @IBAction func swtichCameraRecord(_ sender: UIButton) {
        cameraRecorderStatus.toggle()
        cameraManager.toggleCameraRecorderStatus()
    }
    
    
    
    // MARK: - capture video or record video
    @IBAction func capture(_ sender: UIButton) {
        
        if cameraRecorderStatus.isCamera {
            savePhoto()
        } else {
            cameraManager.controlRecording()
        }
    }
    
    func savePhoto() {
        guard let image = self.monitorView.image else {
            self.alert(title: "저장 실패", message: "저장할 수 없습니다")
            return }
        
        savePhotoLibrary(image: image)
    }
    
    
    func savePhotoLibrary(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { (success, error) in
                    if success {
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
}


