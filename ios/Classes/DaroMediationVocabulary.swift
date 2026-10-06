import Foundation

/// Flutter 채널과 iOS SDK 가 **미디에이션을 서로 다른 이름으로 부른다.** 그 경계가 여기다.
///
/// | | 이름 | 어디서 |
/// | -- | -- | -- |
/// | 채널 | `daro` / `darom` | init 서버 계약. Dart·Android(`DaroMediationType.serverName`)가 쓰는 어휘 |
/// | SDK | `daroa` / `darom` | 공개 표면 `DaroAdInfo.mediationPlatform`. 정본은 `AdProvider.publicName` (DARO-1586) |
/// | SDK (구) | `admob` / `applovin` | 리네임 전 SDK 가 같은 자리에 주던 값 — **`2.0.0-rc.2` 이하**(beta02·beta03·rc.2). 리네임 커밋(`23a3f71d`, 2026-09-01)은 `rc.4` 부터 실린다 |
///
/// **핀 경계에서 셋이 같이 움직인다** (DARO-1684). podspec 핀이 `2.0.0-rc.4` 이상으로 굳는 PR 에서
/// 아래 셋을 한 번에 바꾼다 — 하나만 바꾸면 조용히 틀린다.
///
/// 1. `serverName(forPlatformName:)` 의 구 어휘 케이스 두 줄(`admob`/`applovin`)을 지운다
/// 2. `platformName(forServerName:)` 이 `daroa`/`darom` 을 내게 바꾼다 — 지금은 구 어휘를 내고,
///    리네임 이후 SDK 는 그것을 `AdProvider.matching` 의 **베타 소비자 호환 분기**로만 받는다.
///    SDK 가 그 호환을 걷으면 `openDebugger` 가 `unknown mediation` 으로 거절되는데, 플러그인의
///    `openDebugger` 는 그 오류를 NSLog 만 하고 Dart 에는 성공을 돌려준다 — 검사기가 안 뜨고 아무도 모른다
/// 3. `DaroMediationVocabularyTests` 의 `stillAcceptsLegacyVocabulary…` 와 `platformName_…` 두 테스트를
///    같이 고친다
///
/// 경계를 `rc` 가 아니라 `rc.4` 로 적는 이유: `rc.2` 는 리네임 *전*이라, 거기서 구 어휘를 지우면 이 파일이
/// 고친 바로 그 버그(`mediation` 키가 iOS 에서만 통째로 빠짐)가 재현된다.
///
/// **섞으면 안 된다** — `AdProvider.mediationPlatform` 의 주석이 못을 박아뒀다("init 층 이름과
/// 섞지 않는다 — 다른 이름 공간이다"). 안드로이드는 `DaroMediationType` 이 `serverName` 과
/// `mediationPlatformName` 두 이름을 다 들고 있어 헷갈릴 일이 없는데, iOS SDK 는 바깥에
/// `mediationPlatform` 한쪽만 낸다. 그래서 래퍼가 옮겨야 한다.
///
/// **두 방향을 한 곳에 둔다.** 흩어놓으면 한쪽만 고쳐지고, 그때 나는 증상이 조용하다 —
/// 넘기는 쪽은 SDK 가 `unknown mediation` 으로 떨구고(DARO-1441), 올리는 쪽은 Dart 가
/// 낯선 문자열을 그대로 받아 QA 앱의 비교가 전부 빗나간다(DARO-1556). 어느 쪽도 안 깨진다.
enum DaroMediationVocabulary {

  /// 채널(`daro`/`darom`) → SDK 가 **받는** 이름. 모르는 값이면 `nil`.
  ///
  /// 호출측이 명시한 미디에이션을 SDK 에 넘길 때 쓴다(`openDebugger`). `nil` 을 삼키지 말고 호출자가
  /// 오류로 돌려줘야 한다 — 조용히 넘기면 SDK 가 "지정이 없는 것"으로 처리해 다른 쪽이 열린다.
  ///
  /// **일부러 구 어휘(`admob`/`applovin`)를 낸다.** 핀이 리네임 전 SDK 에 묶여 있고, 그 SDK 는 이 값만
  /// 안다. 리네임 이후 SDK 는 이 값을 호환 분기로 받아준다 — 파일 머리의 "핀 경계" 2번이 이 방향을 언제
  /// `daroa`/`darom` 으로 바꿔야 하는지 적어뒀다.
  static func platformName(forServerName serverName: String) -> String? {
    switch serverName {
    case "daro": return "admob"
    case "darom": return "applovin"
    default: return nil
    }
  }

  /// SDK 가 **주는** 이름(`daroa`/`darom`, 리네임 전 핀은 `admob`/`applovin`) → 채널(`daro`/`darom`).
  /// 모르는 값이면 `nil`.
  ///
  /// SDK 가 준 `DaroAdInfo.mediationPlatform` 을 Dart 로 올릴 때 쓴다. 안드로이드가
  /// `adInfo.mediation?.serverName` 을 싣는 자리의 짝이라 **같은 어휘가 나가야 한다.**
  ///
  /// 두 어휘 집합을 다 받는다 — 핀이 아직 리네임 전이라 그 SDK 와도 살아야 하고, 두 집합이 서로소라
  /// 중복 매칭은 없다. 구 어휘 두 줄을 지우는 시점은 파일 머리의 "핀 경계"(`rc.4` 이상) 하나로 정한다.
  static func serverName(forPlatformName platformName: String) -> String? {
    switch platformName {
    case "daroa", "admob": return "daro"
    case "darom", "applovin": return "darom"
    default: return nil
    }
  }
}
