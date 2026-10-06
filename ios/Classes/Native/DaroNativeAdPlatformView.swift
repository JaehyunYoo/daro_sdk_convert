import Flutter
import Daro

class DaroNativeAdPlatformView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private var nativeAdView: DaroAdNativeView
    private let adId: Int
    private let channel: FlutterMethodChannel

    init(
        frame: CGRect,
        adId: Int,
        adUnitId: String,
        factory: DaroNativeAdFactory,
        preferredAdChoicesPosition: DaroAdChoicesPosition,
        channel: FlutterMethodChannel
    ) {
        self.containerView = UIView(frame: frame)
        self.containerView.backgroundColor = .clear
        self.adId = adId
        self.channel = channel

        let adUnit = DaroAdUnit(unitId: adUnitId)
        self.nativeAdView = factory.createNativeAdView(
            unit: adUnit,
            preferredAdChoicesPosition: preferredAdChoicesPosition
        )

        super.init()

        setupNativeAd()
    }

    func view() -> UIView {
        return containerView
    }

    private func setupNativeAd() {
        nativeAdView.listener.onNativeAdAssetLoaded = { [weak self] assetTypes in
            self?.sendEvent(event: "onNativeAdAssetLoaded", assetTypes: assetTypes.map(\.rawValue))
        }
        nativeAdView.listener.onAdLoadSuccess = { [weak self] (_: DaroAdUnit, adInfo: DaroAdInfo?) in
            guard let self = self else { return }
            self.sendEvent(event: "onAdLoaded", adInfo: adInfo)
        }

        nativeAdView.listener.onAdLoadFail = { [weak self] (error: Error) in
            guard let self = self else { return }
            self.sendEvent(event: "onAdFailedToLoad", error: ["code": -1, "message": error.localizedDescription])
        }

        nativeAdView.listener.onAdClicked = { [weak self] (adInfo: DaroAdInfo?) in
            guard let self = self else { return }
            self.sendEvent(event: "onAdClicked", adInfo: adInfo)
        }

        nativeAdView.listener.onAdImpression = { [weak self] (adInfo: DaroAdInfo?) in
            guard let self = self else { return }
            self.sendEvent(event: "onAdImpression", adInfo: adInfo)
        }

        containerView.addSubview(nativeAdView)
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nativeAdView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            nativeAdView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            nativeAdView.topAnchor.constraint(equalTo: containerView.topAnchor),
            nativeAdView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        nativeAdView.loadAd()
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
