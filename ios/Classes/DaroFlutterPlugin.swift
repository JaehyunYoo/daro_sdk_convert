import Flutter
import UIKit

// `openDebugger` 는 공개 API 가 아니라 `@_spi(DaroQA)` 다 (DARO-1440). 공개로 승격은 나중에
// 할 수 있지만 반대는 못 하므로 SDK 가 그렇게 냈고, 소비자는 이렇게 명시적으로 옵인한다.
// 배포 pod 의 xcframework 가 `.private.swiftinterface` 를 실어 이 import 가 바이너리 경계를
// 넘는다 — 안 실리면 여기서 컴파일이 깨진다(그게 이 의존의 조기 경보다).
@_spi(DaroQA) import Daro

public class DaroFlutterPlugin: NSObject, FlutterPlugin {
  private var interstitialAdManager: DaroInterstitialAdManager?
  private var rewardedAdManager: DaroRewardedAdManager?
  private var appOpenAdManager: DaroAppOpenAdManager?
  private var lightPopupAdManager: DaroLightPopupAdManager?
  private var lightPopupMethodChannel: FlutterMethodChannel?
  private var lightPopupEventChannel: FlutterEventChannel?
  fileprivate var nativeAdViewFactory: DaroNativeAdViewFactory?

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    lightPopupMethodChannel?.setMethodCallHandler(nil)
    lightPopupEventChannel?.setStreamHandler(nil)
    lightPopupAdManager?.detachFromEngine()
    lightPopupAdManager = nil
    lightPopupMethodChannel = nil
    lightPopupEventChannel = nil
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "daro_flutter", binaryMessenger: registrar.messenger())
    let instance = DaroFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.publish(instance)

    let interstitialMethodChannel = FlutterMethodChannel(name: "daro_flutter/interstitial", binaryMessenger: registrar.messenger())
    let interstitialEventChannel = FlutterEventChannel(name: "daro_flutter/interstitial_events", binaryMessenger: registrar.messenger())

    let interstitialManager = DaroInterstitialAdManager()
    instance.interstitialAdManager = interstitialManager

    interstitialMethodChannel.setMethodCallHandler { call, result in
      interstitialManager.handle(call, result: result)
    }
    interstitialEventChannel.setStreamHandler(interstitialManager)

    let rewardedMethodChannel = FlutterMethodChannel(name: "daro_flutter/rewarded", binaryMessenger: registrar.messenger())
    let rewardedEventChannel = FlutterEventChannel(name: "daro_flutter/rewarded_events", binaryMessenger: registrar.messenger())

    let rewardedManager = DaroRewardedAdManager()
    instance.rewardedAdManager = rewardedManager

    rewardedMethodChannel.setMethodCallHandler { call, result in
      rewardedManager.handle(call, result: result)
    }
    rewardedEventChannel.setStreamHandler(rewardedManager)

    let appOpenMethodChannel = FlutterMethodChannel(name: "daro_flutter/appopen", binaryMessenger: registrar.messenger())
    let appOpenEventChannel = FlutterEventChannel(name: "daro_flutter/appopen_events", binaryMessenger: registrar.messenger())

    let appOpenManager = DaroAppOpenAdManager()
    instance.appOpenAdManager = appOpenManager

    appOpenMethodChannel.setMethodCallHandler { call, result in
      appOpenManager.handle(call, result: result)
    }
    appOpenEventChannel.setStreamHandler(appOpenManager)

    let lightPopupMethodChannel = FlutterMethodChannel(name: "daro_flutter/lightpopup", binaryMessenger: registrar.messenger())
    let lightPopupEventChannel = FlutterEventChannel(name: "daro_flutter/lightpopup_events", binaryMessenger: registrar.messenger())

    let lightPopupManager = DaroLightPopupAdManager()
    instance.lightPopupAdManager = lightPopupManager
    instance.lightPopupMethodChannel = lightPopupMethodChannel
    instance.lightPopupEventChannel = lightPopupEventChannel

    lightPopupMethodChannel.setMethodCallHandler { call, result in
      lightPopupManager.handle(call, result: result)
    }
    lightPopupEventChannel.setStreamHandler(lightPopupManager)

    // ad_manager channel: load/destroy for view-based ads (banner / native / line native)
    let adManagerChannel = FlutterMethodChannel(
      name: "daro_flutter/ad_manager",
      binaryMessenger: registrar.messenger()
    )
    adManagerChannel.setMethodCallHandler { call, result in
      instance.handleAdManager(call, result: result, messenger: registrar.messenger(), channel: adManagerChannel)
    }

    let nativeFactory = DaroNativeAdViewFactory(messenger: registrar.messenger())
    registrar.register(
      nativeFactory,
      withId: "daro_native_ad_view"
    )
    instance.nativeAdViewFactory = nativeFactory

    let bannerFactory = DaroBannerAdViewFactory(messenger: registrar.messenger())
    registrar.register(
      bannerFactory,
      withId: "daro_banner_ad_view"
    )

    let lineNativeFactory = DaroLineNativeAdViewFactory(messenger: registrar.messenger())
    registrar.register(
      lineNativeFactory,
      withId: "daro_line_native_ad_view"
    )
  }

  @discardableResult
  public static func registerNativeAdFactory(
    _ registry: FlutterPluginRegistry,
    factoryId: String,
    nativeAdFactory: DaroNativeAdFactory
  ) -> Bool {
    guard let plugin = registry.valuePublished(byPlugin: pluginRegistrationName) as? DaroFlutterPlugin else {
      assertionFailure("Could not find a DaroFlutterPlugin instance. The plugin may have not been registered.")
      return false
    }
    plugin.nativeAdViewFactory?.registerFactory(nativeAdFactory, withId: factoryId)
    return true
  }

  @discardableResult
  public static func unregisterNativeAdFactory(
    _ registry: FlutterPluginRegistry,
    factoryId: String
  ) -> DaroNativeAdFactory? {
    guard let plugin = registry.valuePublished(byPlugin: pluginRegistrationName) as? DaroFlutterPlugin else {
      return nil
    }
    return plugin.nativeAdViewFactory?.unregisterFactory(withId: factoryId)
  }

  private static let pluginRegistrationName = "DaroFlutterPlugin"

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "initialize":
      initializeDaroSDK(call: call, result: result)
    case "setGdpr":
      setGdpr(call: call, result: result)
    case "setCcpa":
      setCcpa(call: call, result: result)
    case "setCoppa":
      setCoppa(call: call, result: result)
    case "setAppMuted":
      let muted = call.arguments as? Bool ?? false
      DaroAds.shared.setAppMuted(muted)
      result(nil)
    case "setUserId":
      let userId = call.arguments as? String
      DaroAds.shared.userId = userId
      result(nil)
    case "openDebugger":
      openDebugger(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleAdManager(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult,
    messenger: FlutterBinaryMessenger,
    channel: FlutterMethodChannel
  ) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "loadBannerAd":
      guard let adId = args["adId"] as? Int,
            let adUnitId = args["adUnitId"] as? String,
            let sizeString = args["size"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
        return
      }

      let bannerSize: DaroAdBannerSize = sizeString == "mrec" ? .MREC : .banner
      let platformView = DaroBannerAdPlatformView(
        frame: .zero,
        adId: adId,
        adUnitId: adUnitId,
        bannerSize: bannerSize,
        channel: channel
      )
      DaroAdInstanceManager.shared.store(platformView, forId: adId)
      result(nil)

    case "loadNativeAd":
      guard let adId = args["adId"] as? Int,
            let adUnitId = args["adUnitId"] as? String,
            let factoryId = args["factoryId"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
        return
      }

      let positionName = args["preferredAdChoicesPosition"] as? String
      let position = DaroAdChoicesPosition.fromName(positionName) ?? .bottomRight

      guard let factory = nativeAdViewFactory?.getFactory(withId: factoryId) else {
        result(FlutterError(code: "FACTORY_NOT_FOUND", message: "Factory not registered: \(factoryId)", details: nil))
        return
      }

      let platformView = DaroNativeAdPlatformView(
        frame: .zero,
        adId: adId,
        adUnitId: adUnitId,
        factory: factory,
        preferredAdChoicesPosition: position,
        channel: channel
      )
      DaroAdInstanceManager.shared.store(platformView, forId: adId)
      result(nil)

    case "loadLineNativeAd":
      guard let adId = args["adId"] as? Int,
            let adUnitId = args["adUnitId"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
        return
      }

      let configuration = DaroLineNativeAdConfiguration()

      if let backgroundColor = args["backgroundColor"] as? [String: Any],
         let color = colorFromMap(backgroundColor) {
        configuration.backgroundColor = color
      }
      if let contentColor = args["contentColor"] as? [String: Any],
         let color = colorFromMap(contentColor) {
        configuration.titleTextColor = color
      }
      if let adMarkLabelTextColor = args["adMarkLabelTextColor"] as? [String: Any],
         let color = colorFromMap(adMarkLabelTextColor) {
        configuration.adMarkTextColor = color
      }
      if let adMarkLabelBackgroundColor = args["adMarkLabelBackgroundColor"] as? [String: Any],
         let color = colorFromMap(adMarkLabelBackgroundColor) {
        configuration.adMarkBackgroundColor = color
      }

      let platformView = DaroLineNativeAdPlatformView(
        frame: .zero,
        adId: adId,
        adUnitId: adUnitId,
        configuration: configuration,
        channel: channel
      )
      DaroAdInstanceManager.shared.store(platformView, forId: adId)
      result(nil)

    case "disposeAd":
      guard let adId = args["adId"] as? Int else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing adId", details: nil))
        return
      }
      DaroAdInstanceManager.shared.remove(forId: adId)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func colorFromMap(_ map: [String: Any]) -> UIColor? {
    guard let r = map["r"] as? Int,
          let g = map["g"] as? Int,
          let b = map["b"] as? Int,
          let a = map["a"] as? Int else {
      return nil
    }
    return UIColor(
      red: CGFloat(r) / 255.0,
      green: CGFloat(g) / 255.0,
      blue: CGFloat(b) / 255.0,
      alpha: CGFloat(a) / 255.0
    )
  }

  private func initializeDaroSDK(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    if let isDebug = args?["isDebugMode"] as? Bool {
      DaroAds.shared.logLevel = isDebug ? .debug : .off
    }
    // **동의를 초기화 앞에 심는다 — 안드로이드 플러그인과 같은 순서다**(coppa → gdpr → ccpa → init).
    // 네이티브 SDK 의 init 은 동의를 받지 않는다. 두 호출을 순서대로 엮는 것이 플러그인의 일이고,
    // Dart 는 `initialize()` 전에 정해둔 값을 payload 로 함께 보낸다.
    //
    // **문자열 키를 읽는다.** 한때 `hasGdprConsent`·`doNotSell` 같은 bool 키만 읽었는데, bool 로는
    // `notApplicable`·`unknown` 을 표현할 수 없어 그 상태가 조용히 사라졌다. Dart 가 두 벌을 다
    // 보내지만 정본은 문자열 쪽이다.
    if let raw = args?["coppaStatus"] {
      guard let status = DaroCoppaStatus.fromNativeName(raw as? String) else {
        return result(Self.invalidConsentStatus("CoppaStatus", raw))
      }
      DaroAds.shared.setCoppa(status)
    }
    if let raw = args?["gdprStatus"] {
      guard let status = DaroGdprStatus.fromNativeName(raw as? String) else {
        return result(Self.invalidConsentStatus("GdprStatus", raw))
      }
      DaroAds.shared.setGdpr(status, consentString: args?["gdprConsentString"] as? String ?? "")
    }
    if let raw = args?["ccpaStatus"] {
      guard let status = DaroCcpaStatus.fromNativeName(raw as? String) else {
        return result(Self.invalidConsentStatus("CcpaStatus", raw))
      }
      DaroAds.shared.setCcpa(status, consentString: args?["ccpaConsentString"] as? String ?? "")
    }

    // **상태 없이 문자열만 온 경우를 받는다.** Dart 는 `gdprStatus` 와 `gdprConsentString` 을
    // 독립 조건으로 싣는다 — 앱이 `DaroFlutter.gdprConsentString` public 필드에 TCF 문자열만
    // 넣고 `setGdpr` 은 안 부를 수 있다(`ccpaConsentString` 도 같다). 위 분기 안에서만 읽으면
    // 그 문자열이 SDK 에 영영 안 닿는다 — 로그도 에러도 없이.
    //
    // **상태가 있으면 여기는 아예 안 돈다** — 위 `setGdpr(_:consentString:)` 이 같은 문자열을
    // 이미 넘겼기 때문이다(빈 문자열이면 SDK 가 무시한다). 그래서 가드가 `== nil` 이다.
    //
    // 세터가 아니라 프로퍼티에 직접 쓰는 것이 맞다 — `gdprConsentString`·`ccpaString` 은
    // deprecated 가 아니고(그 표시는 bool 3종에 붙어 있다), 상태를 모르는 채로 세터를 부르려면
    // 없는 상태를 지어내야 한다. 프로퍼티 쓰기는 벤더로 전파하지 않지만 **여기서는 문제가
    // 안 된다** — 아래 `initialized` 가 `currentPrivacySettings()` 를 새로 읽어 가져간다.
    // 하류에서 실제로 쓰인다: `DaroServingClient` 가 oRTB 요청에, `FyberNetwork` 가 어댑터에
    // 싣는데 **둘 다 `gdprStatus` 를 안 본다.**
    //
    // **여기만 이렇게 동작한다 — 안드로이드에는 이 fallback 이 없다(DARO-1481).**
    // `DaroFlutterPlugin.kt` 는 `gdprString` 을 읽어두고 `gdprStatus?.let { ... }` 안에서만
    // 쓴다. 안드로이드 `Daro.setGdpr` 이 status 를 필수로 받고 상태를 저장하지 않은 채 네트워크로
    // 바로 뿌리는 구조라, 같은 fallback 을 넣으려면 **없는 상태를 지어내야 한다** — 벤더에 실제로
    // 나가는 값이 달라지므로 이 PR 에서 정할 일이 아니다. 여기를 iOS 만의 특례로 남기는 것이
    // 아니라 main 의 iOS 동작을 되살린 것이고(그 전에도 이랬다), 파리티는 별건에서 맞춘다.
    if let gdprString = args?["gdprConsentString"] as? String, args?["gdprStatus"] == nil {
      DaroAds.shared.gdprConsentString = gdprString
    }
    if let ccpaString = args?["ccpaConsentString"] as? String, args?["ccpaStatus"] == nil {
      DaroAds.shared.ccpaString = ccpaString
    }

    DaroAds.shared.initialized { error in
      if let error = error {
        NSLog("[DaroFlutter] initialization failed: \(error.localizedDescription)")
      }
    }
    result(nil)
  }

  // MARK: - 디버거

  private func openDebugger(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    // `nil` 은 **"라우팅 가능한 것 중 첫 번째"**이지 "마지막 로드"가 아니다 — SDK 가 마지막 로드를
    // 기억하지 않는다(DARO-1440). 안드로이드의 `nil` 과 뜻이 갈리는 유일한 지점이라,
    // QA 앱은 iOS 에서 `마지막 로드` 항목을 아예 안 띄운다(`debugger_menu_button.dart`).
    var mapped: String?
    if let serverName = args?["mediation"] as? String {
      guard let platform = DaroMediationVocabulary.platformName(forServerName: serverName) else {
        return result(FlutterError(
          code: "INVALID_MEDIATION",
          message: "Unknown mediation: \(serverName)",
          details: nil
        ))
      }
      mapped = platform
    }

    // **완료를 기다리지 않고 바로 성공을 돌려준다 — 안드로이드와 같은 계약이다.**
    // AdMob 쪽 completion 은 검사기가 *닫힐 때* 온다(GMA 헤더 확인, DARO-1440 PR #180 §알려진 한계).
    // 그것을 Dart `Future` 에 물리면 사용자가 검사기를 닫을 때까지 몇 분씩 안 끝난다.
    // 실패 사유는 삼키지 않고 로그로 남긴다 — Dart 표면에 올리는 것은 시그니처 변경이라 별건이다.
    DaroAds.shared.openDebugger(mediation: mapped) { error in
      if let error {
        NSLog("[DaroFlutter] openDebugger failed: \(error.localizedDescription)")
      }
    }
    result(nil)
  }

  // MARK: - 동의

  private func setGdpr(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let raw = args?["status"]
    guard let status = DaroGdprStatus.fromNativeName(raw as? String) else {
      return result(Self.invalidConsentStatus("GdprStatus", raw))
    }
    DaroAds.shared.setGdpr(status, consentString: args?["consentString"] as? String ?? "")
    result(nil)
  }

  private func setCcpa(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let raw = args?["status"]
    guard let status = DaroCcpaStatus.fromNativeName(raw as? String) else {
      return result(Self.invalidConsentStatus("CcpaStatus", raw))
    }
    DaroAds.shared.setCcpa(status, consentString: args?["consentString"] as? String ?? "")
    result(nil)
  }

  private func setCoppa(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let raw = args?["status"]
    guard let status = DaroCoppaStatus.fromNativeName(raw as? String) else {
      return result(Self.invalidConsentStatus("CoppaStatus", raw))
    }
    DaroAds.shared.setCoppa(status)
    result(nil)
  }

  /// 안드로이드 플러그인과 **같은 코드·같은 문구**를 쓴다 — 앱이 플랫폼별로 분기하지 않게.
  private static func invalidConsentStatus(_ type: String, _ raw: Any?) -> FlutterError {
    FlutterError(
      code: "INVALID_CONSENT_STATUS",
      message: "Unknown \(type): \(raw ?? "null")",
      details: nil
    )
  }
}

/// Dart 의 `nativeName` 문자열을 SDK enum 으로 옮긴다.
///
/// **안드로이드처럼 자동으로는 안 된다.** 그쪽은 enum 이름이 그대로 와이어 값이라
/// `enumValues<T>().firstOrNull { it.name == raw }` 한 줄로 끝나는데, iOS enum 은 `Int` 기반
/// camelCase 라 대응표를 손으로 든다.
///
/// **Dart 쪽 `nativeName` 을 고치면 여기도 같이 고쳐야 한다** — 컴파일러가 안 잡아준다.
/// 정본은 `flutter/packages/daro_flutter/lib/src/consent/daro_consent_status.dart` 다.
private extension DaroGdprStatus {
    static func fromNativeName(_ name: String?) -> DaroGdprStatus? {
        switch name {
        case "OPT_IN":         return .optIn
        case "OPT_OUT":        return .optOut
        case "NOT_APPLICABLE": return .notApplicable
        case "UNKNOWN":        return .unknown
        default:               return nil
        }
    }
}

private extension DaroCcpaStatus {
    static func fromNativeName(_ name: String?) -> DaroCcpaStatus? {
        switch name {
        case "OPT_IN":         return .optIn
        case "OPT_OUT":        return .optOut
        case "NOT_APPLICABLE": return .notApplicable
        default:               return nil
        }
    }
}

private extension DaroCoppaStatus {
    static func fromNativeName(_ name: String?) -> DaroCoppaStatus? {
        switch name {
        case "CHILD":     return .child
        case "NOT_CHILD": return .notChild
        default:          return nil
        }
    }
}

private extension DaroAdChoicesPosition {
    static func fromName(_ name: String?) -> DaroAdChoicesPosition? {
        switch name {
        case "topLeft":     return .topLeft
        case "topRight":    return .topRight
        case "bottomRight": return .bottomRight
        case "bottomLeft":  return .bottomLeft
        default:            return nil
        }
    }
}
