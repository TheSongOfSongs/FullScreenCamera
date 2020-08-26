# Custom Camera
Custom Camera를 구현하여 사진과 비디오를 촬영하고, 필터를 사용하여 다양한 효과를 주는 것이 본 프로젝트의 목표입니다.


# 구현 

## 동작
1. 카메라 뷰로 진입합니다. 오른쪽 상단 아이콘을 눌러 전면, 후면 카메라를 설정할 수 있습니다.
2. 아래쪽 하단 중앙의 버튼을 흰 버튼을 눌러 사진을 촬영할 수 있습니다.
3. 왼쪽 하단의 사진 모양 버튼을 눌러, 갤러리에서 원하는 사진을 선택합니다.
4. 새로운 뷰로 진입하여, 원하는 필터를 적용할 수 있습니다.
5. 오른쪽 상단 '저장' 버튼을 눌러 갤러리에 저장하고 사진 편집하는 뷰는 종료됩니다.

<br/>

## 사용 프레임워크 및 개발 기술
1. AVFoundation Framework - 카메라로 사진 및 동영상 촬영
2. Photos Framework - 앨범에 편집한 사진 저장
3. CoreImage - CIFilter를 이용하여 사진 필터 적용하기
4. GCD와 OperationQueue를 이용한 비동기 처리

<br/>

## 화면 예시
<div>
	<img width="250" src="https://user-images.githubusercontent.com/46002818/86663120-5bd2fc00-c028-11ea-9dd7-0572b610f1d4.png"></img>
	<img width="250" src="https://user-images.githubusercontent.com/46002818/86663072-507fd080-c028-11ea-8c9d-a3d246b648c5.jpeg"></img>
	<img width="250" src = "https://user-images.githubusercontent.com/46002818/86663087-537ac100-c028-11ea-97a9-abc476560095.jpeg"></img>
	</div>

<br/>

## 앞으로 개발 해야 할 사항
1. 동영상 촬영
- AVCaptureMovieFileOutput, AVCaptureVideoDataOutput 이용
- 촬영 버튼 우측의 버튼을 토글하여, 카메라와 동영상 촬영일 경우를 각각 나누어 AVCaptureOutput을 다르게 줄 것으로 계획
2. 실시간으로 카메라 뷰에서 보이는 화면에 필터 적용
- https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcamfilter_applying_filters_to_a_capture_stream
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
