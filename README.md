# Daro Flutter SDK

Flutter 앱에서 Daro 광고를 통합하는 SDK입니다.

## 네이티브 설정 자동 구성

패키지를 추가한 뒤 **앱 루트**(`pubspec.yaml` 옆)에 `daro.yaml`을 작성합니다.
사용하지 않는 플랫폼은 생략할 수 있습니다.

```yaml
ios:
  integration_key: "iOS용 Integration Key"
android:
  integration_key: "Android용 Integration Key"
```

```sh
dart run daro_flutter:configure
dart run daro_flutter:doctor
flutter run
```

`configure`는 설치한 SDK 버전의 요구사항으로 네이티브 프로젝트를 구성합니다.
SDK 업데이트나 키 변경 후 같은 명령을 다시 실행하세요. 같은 설정은 중복으로 추가되지 않습니다.
iOS에서는 설치된 Flutter의 CocoaPods 템플릿·최소 버전을 사용하고,
macOS에서 `pod update DaroAds`를 실행해 네이티브 SDK와 파생 키를 갱신합니다.
키 해제는 기존 네이티브 도구가 수행하며 CLI는 키를 출력하지 않습니다.
생성·변경된 네이티브 파일에도 키가 들어가므로 `daro.yaml`과 함께 앱 설정으로 관리하세요.

`doctor`는 프로젝트 파일을 수정하지 않고 설정 누락과 기본 도구 요구사항을 검사합니다.
iOS는 설치된 DaroAds 도구로 현재 integration key를 임시 plist에서 복호화하여
실제 Info.plist의 파생 키 4개와 비교합니다. 누락·불일치·복호화 실패·도구 부재는 실패로 보고하며 키 값은 출력하지 않습니다.
실패 시 종료 코드 1과 필요한 조치를 반환합니다. 실제 의존성 해석·컴파일 검증은 Flutter 빌드로 완료하세요.

현재 자동 구성 대상은 기본 Flutter 앱 구조(Android `app` 모듈, iOS `Runner`)입니다.
Android는 Groovy/Kotlin DSL을 지원하며 프로젝트 수준 저장소를 사용합니다.
`dependencyResolutionManagement`, product flavors, 커스텀 iOS target/plist,
루트 Gradle의 imports/plugins 블록은 수정 전에 진단하고 중단합니다.
기존에 Daro를 수동 설정한 앱은 기존 Daro classpath·plugin 적용·키 주입 훅을 제거한 뒤 실행하세요.
고객사 고유 설정은 유지하고 최소 OS·compileSdk는 필요한 경우에만 올립니다.
JDK·Gradle·AGP·Kotlin 자체를 자동 업그레이드하지는 않습니다.

## Documentation

자세한 연동 가이드 및 API 문서: [Daro 연동 가이드](https://guide.daro.so/ko/sdk-integration/flutter/get-started)
