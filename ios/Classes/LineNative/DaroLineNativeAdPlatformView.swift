import Flutter
import Daro

class DaroLineNativeAdPlatformView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private var lineNativeAdView: DaroAdLineBannerView
    private let adId: Int
    private let channel: FlutterMethodChannel

    init(
        frame: CGRect,
        adId: Int,
        adUnitId: String,
        configuration: DaroLineNativeAdConfiguration,
        channel: FlutterMethodChannel
    ) {
        self.containerView = UIView(frame: frame)
        self.containerView.backgroundColor = .clear
        self.adId = adId
        self.channel = channel

        let adUnit = DaroAdUnit(unitId: adUnitId)
        self.lineNativeAdView = DaroAdLineBannerView(unit: adUnit, autoLoad: false)
        self.lineNativeAdView.configuration = configuration

        super.init()

        setupLineNativeAd()
    }

    func view() -> UIView {
        return containerView
    }

    private func setupLineNativeAd() {
        lineNativeAdView.listener.onNativeAdAssetLoaded = { [weak self] assetTypes in
            self?.sendEvent(event: "onNativeAdAssetLoaded", assetTypes: assetTypes.map(\.rawValue))
        }
        lineNativeAdView.listener.onAdLoadSuccess = { [weak self] (_: DaroAdUnit, adInfo: DaroAdInfo?) in
            guard let self = self else { return }
            self.sendEvent(event: "onAdLoaded", adInfo: adInfo)
        }

        lineNativeAdView.listener.onAdLoadFail = { [weak self] (error: Error) in
            guard let self = self else { return }
            self.sendEvent(event: "onAdFailedToLoad", error: ["code": -1, "message": error.localizedDescription])
        }

        lineNativeAdView.listener.onAdClicked = { [weak self] (adInfo: DaroAdInfo?) in
            guard let self = self else { return }
            self.sendEvent(event: "onAdClicked", adInfo: adInfo)
        }

        lineNativeAdView.listener.onAdImpression = { [weak self] (adInfo: DaroAdInfo?) in
            guard let self = self else { return }
            self.sendEvent(event: "onAdImpression", adInfo: adInfo)
        }

        containerView.addSubview(lineNativeAdView)
        lineNativeAdView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lineNativeAdView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            lineNativeAdView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            lineNativeAdView.topAnchor.constraint(equalTo: containerView.topAnchor),
            lineNativeAdView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        lineNativeAdView.loadAd()
    }

    /// `adInfo` 는 **뷰형 계약이라 `adUnitId`·`format` 을 안 싣는다** — Dart 위젯이 자기 필드로
    /// 채운다(`daro_native_ad.dart` 의 `_createAdInfo`). 안드로이드 뷰 쪽과 같은 모양이다.
    private func sendEvent(event: String, error: [String: Any]? = nil, adInfo: DaroAdInfo? = nil, assetTypes: [String]? = nil) {
        var arguments: [String: Any] = [
            "adId": adId,
            "event": event,
        ]

        if let error = error {
            arguments["error"] = error
        }

        if let adInfo {
            arguments["adInfo"] = adInfo.flutterCommonFields
        }

        if let assetTypes {
            arguments["assetTypes"] = assetTypes
        }

        channel.invokeMethod("onAdEvent", arguments: arguments)
    }
}
