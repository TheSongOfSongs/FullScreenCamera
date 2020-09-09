import UIKit
import AVFoundation
import Photos
import CoreImage
import GPUImage

let blendImageName = "WID-small.jpg"

class CameraViewController: UIViewController {
    
    var camera: Camera!
    
    var blendImage:PictureInput?
    
    var filterOperation: FilterOperationInterface?
    
    let cameraManager = CameraManager()
    
    let filterManager = FilterManager.shared
    
    private lazy var filterView: UIView = {
        let renderViewSize = self.renderView.frame.size
        let frame = CGRect(x: 0, y: self.view.frame.height - 150, width: self.view.frame.size.width, height: 130)
        
        let filterView = FilterCollection(frame: frame)
        return filterView
    }()
    
    var cameraRecorderStatus: CameraRecorder = .camera {
        didSet {
            if cameraRecorderStatus.isCamera {
                captureButton.backgroundColor = .white
            } else {
                captureButton.backgroundColor = .red
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
    @IBOutlet weak var renderView: RenderView!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            camera = try Camera(sessionPreset:.vga640x480, location:.backFacing)
        } catch {
            camera = nil
            print("Couldn't initialize camera with error: \(error)")
        }
        filterOperation = filterOperations[8]
        self.configureView()
        
        setupUI()
//        cameraManager.videoSavingCompletion = { success in
//            if success {
//                self.alert(title: "저장 성공", message: "사진에서 확인해보세요!")
//            } else {
//                self.alert(title: "저장 실패", message: "저장할 수 없습니다")
//            }
        //        }
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
        
        cameraManager.captureButtonCompletion = { isRecording in
            DispatchQueue.main.async {
                self.captureButton.backgroundColor = isRecording ? .orange : .red
            }
        }
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
//        guard let image = self.renderViewSize.image else {
//            self.alert(title: "저장 실패", message: "저장할 수 없습니다")
//            return
//        }
//
//        savePhotoLibrary(image: image)
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
    
    func configureView() {
        guard let videoCamera = camera else {
            let errorAlertController = UIAlertController(title: NSLocalizedString("Error", comment: "Error"), message: "Couldn't initialize camera", preferredStyle: .alert)
            errorAlertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            self.present(errorAlertController, animated: true, completion: nil)
            return
        }
        if let currentFilterConfiguration = self.filterOperation {
            self.title = currentFilterConfiguration.titleName
            
            // Configure the filter chain, ending with the view
            if let view = self.renderView {
                switch currentFilterConfiguration.filterOperationType {
                case .singleInput:
                    videoCamera.addTarget(currentFilterConfiguration.filter)
                    currentFilterConfiguration.filter.addTarget(view)
                case .blend:
                    videoCamera.addTarget(currentFilterConfiguration.filter)
                    self.blendImage = PictureInput(imageName:blendImageName)
                    self.blendImage?.addTarget(currentFilterConfiguration.filter)
                    self.blendImage?.processImage()
                    currentFilterConfiguration.filter.addTarget(view)
                case let .custom(filterSetupFunction:setupFunction):
                    currentFilterConfiguration.configureCustomFilter(setupFunction(videoCamera, currentFilterConfiguration.filter, view))
                }
                
                videoCamera.startCapture()
            }
        }
    }
}
