import Foundation
import Daro

extension DaroAdInfo {

  /// Dart `DaroAdInfo` 가 읽는 필드 중 **SDK 가 주는 것**만 담는다.
  ///
  /// `adUnitId` 와 `format` 은 여기 없다 — 호출측이 얹는다. 매니저는 자기 포맷을 알고 있고,
  /// 플랫폼 뷰(배너·네이티브·라인네이티브)는 그 둘을 Dart 가 자기 필드로 채운다
  /// (`daro_native_ad.dart` 의 `_createAdInfo`). 안드로이드 뷰 쪽 `adInfoToMap` 과 같은 모양이다.
  ///
  /// **없는 값은 키를 안 넣는다.** Dart 의 `DaroAdInfo.fromMap` 이 없는 키를 `nil` 로 받으므로
  /// `NSNull` 을 넣는 것보다 이쪽이 안전하다 — `as? String` 캐스팅이 `NSNull` 에서 `nil` 로
  /// 떨어지긴 하지만, 키가 없는 것과 값이 비었다는 것을 굳이 구분해 보낼 이유가 없다.
  var flutterCommonFields: [String: Any] {
    var map: [String: Any] = [:]

    // **어휘를 옮긴다** — SDK 공개 어휘 → 채널 어휘. 표는 `DaroMediationVocabulary` 한 곳이고 여기에
    // 값을 다시 적지 않는다(적으면 이 주석이 또 낡는다 — 실제로 그랬다, DARO-1684).
    // 그대로 올리면 QA 앱이 `lastMediation` 을 채널 어휘와 비교하는 자리가 전부 빗나가고,
    // 고객사가 안드로이드와 같은 문자열을 기대하는 자리도 어긋난다.
    //
    // **매핑이 빗나가면 키를 빼되 소리를 낸다.** SDK 가 어휘를 또 바꾸면 이 자리가 조용히 `nil` 이 되는데,
    // 그것을 로그 없이 넘기는 바람에 지난번엔 안드로이드와 손으로 대조해서야 드러났다.
    if let platform = mediationPlatform {
      if let serverName = DaroMediationVocabulary.serverName(forPlatformName: platform) {
        map["mediation"] = serverName
      } else {
        NSLog("[DaroFlutter] unmapped mediationPlatform '\(platform)' — 'mediation' omitted; update DaroMediationVocabulary")
      }
    }

    // 벤더 어휘 그대로다 — SDK 가 정규화하지 않는다고 `DaroAdInfo.adNetwork` 주석이 밝혀뒀다.
    if let adNetwork {
      map["adNetwork"] = adNetwork
    }

    // 밀리초. SDK 가 주는 값을 그대로 올린다 — 단위 변환은 SDK 안에서 이미 끝났다
    // (`AdMob+.swift` · `AppLovin+.swift`). Dart 가 `(map['latency'] as num?)?.toInt()` 로 받는다.
    //
    // **정의가 Android 와 다르다는 것은 알고 올린다** — iOS 는 워터폴 시도 전부의 합이고
    // Android 는 낙찰 어댑터 하나다(DARO-1555). 그것을 맞추는 것은 SDK 쪽 일이라 여기서
    // 손대지 않는다. 여기서 보정하면 SDK 를 고칠 때 두 번 보정된다.
    if let latency {
      map["latency"] = latency
    }

    return map
  }
}
