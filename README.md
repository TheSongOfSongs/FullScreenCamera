# Custom Camera (v.1)
Custom Camera를 구현하여 사진과 비디오를 촬영하고, 필터를 사용하여 다양한 효과를 주는 것이 본 프로젝트의 목표입니다.


# 구현 

## 동작
1. 카메라 뷰로 진입합니다. 오른쪽 상단 아이콘을 눌러 전면, 후면 카메라를 설정할 수 있습니다.
2. 아래쪽 하단 중앙의 버튼을 흰 버튼을 눌러 사진을 촬영할 수 있습니다.
3. 왼쪽 하단의 사진 모양 버튼을 눌러, 갤러리에서 원하는 사진을 선택할 수 있습니다.
4. 카메라, 비디오, 선택된 사진은 하단의 '필터' 버튼을 통해 원하는 필터 적용이 가능합니다.

<br/>

## 사용 프레임워크 및 개발 기술
1. AVFoundation Framework - 카메라로 사진 및 동영상 촬영
2. Photos Framework - 앨범에 편집한 사진 저장
3. CoreImage - CIFilter를 이용하여 사진 필터 적용하기
4. GCD와 OperationQueue를 이용한 비동기 처리

<br/>

## 화면 예시
<div>
  <img width="200" src = "https://user-images.githubusercontent.com/46002818/95294991-35379200-08b1-11eb-8b32-057de0ea3dd0.JPG"></img>
	<img width="200" src = "https://user-images.githubusercontent.com/46002818/95294989-35379200-08b1-11eb-9007-af3c3d6cce14.JPG"></img>
	</div>
	<img width="160" src="https://user-images.githubusercontent.com/46002818/95295214-9bbcb000-08b1-11eb-999e-d9f0d3ab2300.jpeg"></img>
	<img width="160" src="https://user-images.githubusercontent.com/46002818/95294975-2e108400-08b1-11eb-9b4b-74f35287a2b2.PNG"></img>
	<img width="160" src="https://user-images.githubusercontent.com/46002818/95294987-34066500-08b1-11eb-974f-7dad57814ee9.PNG"></img>
	

## 앞으로 개발 해야 할 사항
1. 동영상 화질 개선

2. MetalKit을 이용하여 필터의 커스터마이징
https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcamfilter_applying_filters_to_a_capture_stream
- 위 링크와 예제 파일을 참조하여 MetalKit 

<br/>

## 참조 문서
- 아래 링크 문서, 문서에서 다운받을 수 있는 소스 코드
[https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcam_building_a_camera_app](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcam_building_a_camera_app)

<br/>

## 개발 환경 
- swift5
 - iOS13.0
 - Xcode11.5



## Version History
### Version0
- 사진 촬영 후 저장
- 사진 선택하여 필터 씌인 후 저장

### Version1
- AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate를 이용하여
  실시간으로 비디오와 오디오를 버퍼로 받아 타임스탬프와 함께 AVAssetWriterInput(오디오)와 AVAssetWriterInputPixelBufferAdaptor(비디오)에 추가.

- 사용자가 카메라로 들어오는 Input을 확인할 수 있도록, 들어오는 버퍼는 이미지로 변환하여 callback을 통해 뷰 컨트롤러에 띄우주는 방식 이용.

- 화면의 필터를 씌우기 위해 버퍼를 필터를 건 CIImage 로 바꾸고, 비디오는 다시 픽셀 버퍼로 변경한 다음 AVAssetWriterInputPixelBufferAdaptor에 추가.
  필터 적용된 사진을 위해, 뷰 컨트롤러에서 CIImage를 CGImage로 바꾼 다음 다시 UIImage로 변경
