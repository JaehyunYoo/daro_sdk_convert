Pod::Spec.new do |s|
  s.name             = 'daro_flutter'
  s.version          = '2.0.0'
  s.summary          = 'Daro Flutter SDK'
  s.description      = 'Daro Flutter SDK'
  s.homepage         = 'https://github.com/delightroom/daro-ios-sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Delightroom' => 'dev@delightroom.so' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.static_framework = true
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # **통합 SDK 2.0 이다** — 레거시 `DaroAds` 1.x 가 아니다. 이름이 `Daro` 로 바뀌었다.
  #
  # 1.x 에는 `DaroGdprStatus`·`DaroCcpaStatus`·`DaroCoppaStatus` 와 그 세터가 없다. 그래서 iOS 쪽
  # 동의 배선이 deprecated bool API 에 묶여 있었고 `notApplicable`·`unknown` 이 표현 불가였다
  # (DARO-1471).
  #
  # **pod 이름은 `DaroAds` 그대로다 — 통합 SDK 도 그 이름으로 발행된다.** 2.0 부터 내용물이
  # 통합본으로 바뀌었을 뿐 좌표는 안 옮겼다. 모듈 이름만 `Daro` 다(`import Daro`) — vendored
  # framework 의 모듈명은 pod 이름이 아니라 `Daro.xcframework` 자신이 정한다.
  #
  # **`Daro` 라는 이름으로 핀하지 않는다.** 그 좌표는 CocoaPods trunk 에 없어서, 물리는 순간
  # 소비 앱 Podfile 마다 `pod 'Daro', :podspec => <릴리스 URL>` 한 줄을 손으로 넣어야 한다 —
  # 우리 배포 사정을 고객사에 떠넘기는 배선이고, 실제로 그렇게 나갈 뻔했다.
  # `DaroAds 2.0.0-beta02` 는 trunk 에 있고 **같은 `Daro.xcframework.zip` 자산을 가리킨다.**
  s.dependency 'DaroAds', '2.0.1'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
