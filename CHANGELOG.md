## 2.0.0

- iOS Native SDK: DaroAds 2.0.1
- Android Native SDK: daro-sdk 2.0.1

- Android 네이티브 SDK를 2.0.1, Android Gradle 플러그인을 2.0.0으로 업데이트했습니다.
- iOS 네이티브 SDK DaroAds를 2.0.1으로 업데이트했습니다.
- daro.yaml을 통한 네이티브 연동 설정을 지원합니다.
- 네이티브 광고의 제공 에셋을 확인하는 콜백을 추가했습니다.
- 라이트팝업의 네이티브 기본 UI 연동과 요청 수명주기 처리를 개선했습니다.

## 2.0.0-beta03

- iOS Native SDK: DaroAds 2.0.0-beta02
- Android Native SDK: daro-sdk 2.0.0-beta14
- Release date: 2026-08-27

### `placement` 입력을 걷는다 — SDK 가 애드유닛 식별자로 채운다

`DaroInterstitialAd` · `DaroRewardedAd` · `DaroAppOpenAd` · `DaroLightPopupAd` 의
`placement` 파라미터가 사라진다. 넘기던 값이 있으면 인자를 지우면 된다.

AppLovin 으로 나가는 요청의 placement 는 이제 네이티브 SDK 가 애드유닛 식별자로 채운다.
서버 리포트가 숫자 placement 만 애드유닛에 매칭하므로 임의 문자열은 집계에서 빠졌다.

Android 는 `daro-sdk 2.0.0-beta14` 가 그 동작을 담는다. iOS 네이티브 대응은 별도로
진행 중이라 이번 판에서 iOS 요청에는 placement 가 실리지 않는다.

### 네이티브 광고의 비디오 크리에이티브가 제자리에 그려진다

이전에는 영상이 위젯에서 떨어져 화면 상단에 붙었다. 네이티브 광고 위젯의 PlatformView
합성 방식을 Hybrid Composition 으로 바꿨다. 이미지 크리에이티브에서는 나타나지 않던 증상이다.

## 2.0.0-beta02

- iOS Native SDK: DaroAds 2.0.0-beta02
- Android Native SDK: daro-sdk 2.0.0-beta13
- Release date: 2026-08-26

### iOS 핀이 trunk 의 `DaroAds` 로 돌아온다 — Podfile 에 손댈 것이 없다

beta01 은 iOS 의존을 `Daro 2.0.0-beta02` 로 핀했는데, 그 좌표는 CocoaPods trunk 에 없다.
그래서 소비 앱마다 Podfile 에 `pod 'Daro', :podspec => <릴리스 URL>` 한 줄을 손으로 넣어야
`pod install` 이 통과했다. beta02 는 `DaroAds 2.0.0-beta02` 를 핀한다 — trunk 에 있고
**같은 `Daro.xcframework.zip` 자산을 가리킨다.**

**beta01 에서 넣은 그 줄은 지운다.** 남겨두면 두 좌표가 같은 바이너리를 이중으로 물어
`pod install` 이 충돌한다.

**pod 이름은 `DaroAds`, 모듈 이름은 `Daro` 다.** Swift 에서는 `import Daro` 를 쓴다 —
vendored framework 의 모듈명은 pod 이름이 아니라 `Daro.xcframework` 자신이 정한다.

동의 API 배선과 COPPA 적용 범위는 beta01 과 같다. 아래 beta01 항목을 그대로 읽으면 된다.


## 2.0.0-beta01

- iOS Native SDK: Daro 2.0.0-beta02
- Android Native SDK: daro-sdk 2.0.0-beta13
- Release date: 2026-08-26

### ⚠️ iOS 통합을 손봐야 한다 — 발행 전 반드시 읽는다

iOS 네이티브 의존이 레거시 `DaroAds`(1.x) 에서 **통합 SDK `Daro`(2.0)** 로 바뀐다.
pod 이름 자체가 달라진다. Android 는 이미 통합 SDK 였고 iOS 만 남아 있었다.

**소비자 Podfile 에 한 줄이 필요하다.** 통합 pod 은 아직 CocoaPods trunk 에 없다.

```ruby
target 'Runner' do
  pod 'Daro', :podspec => 'https://github.com/delightroom/daro-ios-sdk/releases/download/v2.0.0-beta02/Daro.podspec'
  # ...
end
```

이 줄이 없으면 `pod install` 이 다음으로 멈춘다.

```
None of your spec sources contain a spec satisfying the dependency: Daro (= 2.0.0-beta02)
```

레거시 `DaroAds` 는 trunk 에 있어서 수동 배선이 필요 없었다 — **없던 요구가 새로 생긴 것이다.**
정식 채널이 열리면 이 줄은 없어진다.

**버전을 올릴 때는 `pod update Daro` 다 — `pod install` 이 아니다.** external `:podspec` 은
`pod install` 이 lock 의 이전 버전을 계속 참조해서, 리소스 번들이 없는 옛 바이너리로 빌드되고
서빙 렌더 시점에 크래시한다.

### ⚠️ COPPA 적용 범위가 줄어든다

`DaroFlutter.setCoppa` 가 iOS 에서 처음 동작하게 되는데, **동시에 적용 범위가 줄어든다.**
통합 SDK 는 AdMob 과 AppLovin 을 함께 싣는데 AppLovin SDK 13.x 가 age-restricted API 를
제거해서 **AppLovin 으로 라우팅된 트래픽에는 COPPA 가 전달되지 않는다.** 에러도 로그도 없다.

아동 대상 앱은 트래픽 가중치를 `daro 100 / darom 0` 으로 두어야 한다.

### 고침

- **iOS 에서 `setGdpr`·`setCcpa`·`setCoppa` 가 실제로 동작한다.** 그전에는 네이티브 채널에
  핸들러가 없어 `MissingPluginException` 이 났고, Dart 가 그것을 삼켜 **성공한 것처럼 보였다.**
  화면과 로그가 성공을 말하는데 SDK 에는 아무것도 안 가는 상태였다.
- **iOS 가 `notApplicable`·`unknown` 을 받는다.** 이전에는 초기화 경로가 bool API 만 읽어
  그 두 상태를 표현할 수 없었다.


## 1.0.6

- iOS Native SDK: DaroAds 1.1.61
- Android Native SDK: daro-a 1.5.5
- Release date: 2026-05-20


## 1.0.5

- iOS Native SDK: DaroAds 1.1.59
- Android Native SDK: daro-a 1.5.5
- Release date: 2026-05-18


## 1.0.4

- iOS Native SDK: DaroAds 1.1.58
- Android Native SDK: daro-a 1.5.5
- Release date: 2026-05-12


## 1.0.3

- iOS Native SDK: DaroAds 1.1.57
- Android Native SDK: daro-a 1.5.5
- Release date: 2026-04-28


## plugin-v1.0.1

- iOS Native SDK: DaroAds 1.1.55
- Android Native SDK: daro-a 1.5.1
- Release date: 2026-03-20


## 1.0.2

- iOS Native SDK: DaroAds 1.1.51
- Android Native SDK: daro-a 1.4.2
- Release date: 2026-02-24


## 1.0.1

- iOS Native SDK: DaroAds 1.1.50
- Android Native SDK: daro-a 1.4.2
- Release date: 2026-02-19


## 1.0.0

- iOS Native SDK: DaroAds 1.1.50
- Android Native SDK: daro-a 1.4.2
- Release date: 2026-02-04


# Changelog

## 0.0.2

- iOS Native SDK: DaroAds 1.1.50
- Android Native SDK: daro-a 1.4.2
- Release date: 2026-02-04