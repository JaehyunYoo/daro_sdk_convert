import Flutter
import UIKit
import Daro

class DaroLightPopupAdManager: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private final class Request {
        let instanceId: String
        let adUnitId: String
        let requestId: Int
        var loader: DaroLightPopupAdLoader?
        var ad: DaroLightPopupAd?
        var showing = false
        weak var presentedController: UIViewController?

        init(instanceId: String, adUnitId: String, requestId: Int) {
            self.instanceId = instanceId
            self.adUnitId = adUnitId
            self.requestId = requestId
        }
    }
    private var requests: [String: Request] = [:]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "loadAd":
            loadAd(call, result: result)
        case "isAdReady":
            isAdReady(call, result: result)
        case "showAd":
            showAd(call, result: result)
        case "destroyAd":
            destroyAd(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func extractAdUnitId(from call: FlutterMethodCall, result: @escaping FlutterResult) -> String? {
        guard let args = call.arguments as? [String: Any],
              let adUnitId = args["adUnitId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing adUnitId", details: nil))
            return nil
        }
        return adUnitId
    }

    private func loadAd(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let adUnitId = extractAdUnitId(from: call, result: result) else { return }

        let args = call.arguments as? [String: Any]
        let instanceId = args?["instanceId"] as? String ?? adUnitId
        release(instanceId)
        let request = Request(instanceId: instanceId, adUnitId: adUnitId, requestId: args?["requestId"] as? Int ?? 0)
        requests[instanceId] = request
        let configuration = buildConfiguration(from: args)
        let loader = DaroLightPopupAdLoader(unit: DaroAdUnit(unitId: adUnitId))
        request.loader = loader

        loader.listener.onAdLoadSuccess = { [weak self, weak request] ad, adInfo in
            guard let self, let request, self.isCurrent(request) else { return }
            ad.configuration = configuration
            request.ad = ad
            self.setupAdListener(request: request, ad: ad)
            self.sendAdInfoEvent(eventType: "onAdLoadSuccess", request: request, adInfo: adInfo)
        }
        loader.listener.onAdLoadFail = { [weak self, weak request] error in
            guard let self, let request, self.isCurrent(request) else { return }
            self.sendAdLoadErrorEvent(eventType: "onAdLoadFail", request: request, error: error)
            self.finish(request, dismiss: false)
        }
        loader.listener.onAdClicked = { [weak self, weak request] adInfo in
            guard let self, let request, request.ad != nil else { return }
            self.sendAdInfoEvent(eventType: "onAdClicked", request: request, adInfo: adInfo)
        }
        loader.listener.onAdImpression = { [weak self, weak request] adInfo in
            guard let self, let request, request.ad != nil else { return }
            self.sendAdInfoEvent(eventType: "onAdImpression", request: request, adInfo: adInfo)
        }

        loader.loadAd()
        result(nil)
    }

    private func buildConfiguration(from args: [String: Any]?) -> DaroLightPopupConfiguration {
        let configuration = DaroLightPopupConfiguration()

        if let map = args?["backgroundColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.backgroundColor = color
        }
        if let map = args?["containerColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.cardViewBackgroundColor = color
        }
        if let map = args?["adMarkLabelTextColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.adMarkLabelTextColor = color
        }
        if let map = args?["adMarkLabelBackgroundColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.adMarkLabelBackgroundColor = color
        }
        if let map = args?["titleColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.titleTextColor = color
        }
        if let map = args?["bodyColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.bodyTextColor = color
        }
        if let map = args?["ctaBackgroundColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.ctaButtonBackgroundColor = color
        }
        if let map = args?["ctaTextColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.ctaButtonTextColor = color
        }
        if let closeButtonText = args?["closeButtonText"] as? String {
            configuration.closeButtonText = closeButtonText
        }
        if let map = args?["closeButtonColor"] as? [String: Any], let color = colorFromMap(map) {
            configuration.closeButtonTextColor = color
        }

        return configuration
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

    private func setupAdListener(request: Request, ad: DaroLightPopupAd) {
        ad.lightPopupAdListener.onShown = { [weak self, weak request] adInfo in
            guard let self, let request, request.ad != nil else { return }
            self.sendAdInfoEvent(eventType: "onAdShown", request: request, adInfo: adInfo)
        }
        ad.lightPopupAdListener.onFailedToShow = { [weak self, weak request] _, error in
            guard let self, let request, self.isCurrent(request), request.ad != nil else { return }
            self.finish(request, dismiss: false)
            self.sendAdDisplayErrorEvent(eventType: "onAdFailedToShow", request: request, error: error)
        }
        ad.lightPopupAdListener.onDismiss = { [weak self, weak request] adInfo in
            guard let self, let request, self.isCurrent(request), request.ad != nil else { return }
            self.finish(request, dismiss: false)
            self.sendAdInfoEvent(eventType: "onAdDismiss", request: request, adInfo: adInfo)
        }
    }

    private func isAdReady(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let adUnitId = extractAdUnitId(from: call, result: result) else { return }

        let request = matchingRequest(from: call, adUnitId: adUnitId)
        let ready = request?.ad != nil && request?.showing == false
        result(ready)
    }

    private func showAd(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let adUnitId = extractAdUnitId(from: call, result: result) else { return }

        guard let request = matchingRequest(from: call, adUnitId: adUnitId),
              let ad = request.ad, !request.showing else {
            result(FlutterError(code: "AD_NOT_LOADED", message: "Ad not loaded", details: nil))
            return
        }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "No view controller available", details: nil))
            return
        }

        var topViewController = viewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        request.showing = true
        ad.show(viewController: topViewController)
        // Retain only ownership of the controller that this successful show
        // presented. A rejected show must never dismiss an unrelated modal.
        if request.ad === ad {
            request.presentedController = topViewController.presentedViewController
        }
        result(nil)
    }

    private func destroyAd(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let adUnitId = extractAdUnitId(from: call, result: result) else { return }

        release(instanceId(from: call, adUnitId: adUnitId))
        result(nil)
    }

    private func instanceId(from call: FlutterMethodCall, adUnitId: String) -> String {
        (call.arguments as? [String: Any])?["instanceId"] as? String ?? adUnitId
    }

    private func matchingRequest(from call: FlutterMethodCall, adUnitId: String) -> Request? {
        let requestId = (call.arguments as? [String: Any])?["requestId"] as? Int ?? 0
        guard let request = requests[instanceId(from: call, adUnitId: adUnitId)],
              request.requestId == requestId else { return nil }
        return request
    }

    private func isCurrent(_ request: Request) -> Bool {
        requests[request.instanceId] === request
    }

    private func finish(_ request: Request, dismiss: Bool) {
        request.loader?.listener.onAdLoadSuccess = nil
        request.loader?.listener.onAdLoadFail = nil
        request.loader?.listener.onAdClicked = nil
        request.loader?.listener.onAdImpression = nil
        request.ad?.lightPopupAdListener.onShown = nil
        request.ad?.lightPopupAdListener.onFailedToShow = nil
        request.ad?.lightPopupAdListener.onDismiss = nil
        request.loader = nil
        request.ad = nil
        request.showing = false
        let controller = request.presentedController
        request.presentedController = nil
        // The published native API has no destroy/cancel. Revoke callbacks and
        // dismiss our own presentation; an in-flight native load may still finish.
        if dismiss, let controller, controller.presentingViewController != nil {
            if controller.isBeingPresented, let transition = controller.transitionCoordinator {
                transition.animate(alongsideTransition: nil) { [weak controller] _ in
                    controller?.dismiss(animated: false)
                }
            } else {
                controller.dismiss(animated: false)
            }
        }
    }

    private func release(_ instanceId: String) {
        guard let request = requests.removeValue(forKey: instanceId) else { return }
        finish(request, dismiss: true)
    }

    func detachFromEngine() {
        eventSink = nil
        for instanceId in Array(requests.keys) { release(instanceId) }
    }

    private func adInfoToMap(_ adInfo: DaroAdInfo?, adUnitId: String) -> [String: Any] {
        var map = adInfo?.flutterCommonFields ?? [:]
        map["adUnitId"] = adUnitId
        map["format"] = "lightpopup"
        return map
    }

    private func sendAdInfoEvent(eventType: String, request: Request, adInfo: DaroAdInfo?) {
        sendEvent(request, [
            "eventType": eventType,
            "adUnitId": request.adUnitId,
            "adInfo": adInfoToMap(adInfo, adUnitId: request.adUnitId)
        ])
    }

    private func sendAdLoadErrorEvent(eventType: String, request: Request, error: DaroError) {
        sendEvent(request, [
            "eventType": eventType,
            "adUnitId": request.adUnitId,
            "error": [
                "code": error.code.rawValue,
                "message": error.message,
                "adUnitId": request.adUnitId
            ]
        ])
    }

    private func sendAdDisplayErrorEvent(eventType: String, request: Request, error: DaroError) {
        sendEvent(request, [
            "eventType": eventType,
            "adUnitId": request.adUnitId,
            "error": [
                "code": error.code.rawValue,
                "message": error.message
            ]
        ])
    }

    private func sendEvent(_ request: Request, _ event: [String: Any]) {
        DispatchQueue.main.async { [weak self, weak request] in
            guard let self, let request, self.isCurrent(request) else { return }
            var payload = event
            payload["instanceId"] = request.instanceId
            payload["requestId"] = request.requestId
            self.eventSink?(payload)
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
