package so.daro.flutter

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import droom.daro.core.adunit.DaroLightPopupAdUnit
import droom.daro.core.listener.DaroLightPopupAdListener
import droom.daro.core.listener.DaroLightPopupAdLoaderListener
import droom.daro.core.model.DaroAdDisplayFailError
import droom.daro.core.model.DaroAdInfo
import droom.daro.core.model.DaroAdLoadError
import droom.daro.core.model.DaroLightPopupAd
import droom.daro.core.model.DaroLightPopupAdOptions
import droom.daro.loader.DaroLightPopupAdLoader

class DaroFlutterLightPopupAdManager : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private class Request(val instanceId: String, val adUnitId: String, val requestId: Int) {
        var loader: DaroLightPopupAdLoader? = null
        var ad: DaroLightPopupAd? = null
        var showing = false
    }
    private val requests = mutableMapOf<String, Request>()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setContext(context: Context?) {
        this.context = context
    }

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadAd" -> loadAd(call, result)
            "isAdReady" -> isAdReady(call, result)
            "showAd" -> showAd(call, result)
            "destroyAd" -> destroyAd(call, result)
            else -> result.notImplemented()
        }
    }

    private fun extractAdUnitId(call: MethodCall, result: MethodChannel.Result): String? {
        val adUnitId = call.argument<String>("adUnitId")
        if (adUnitId == null) {
            result.error("INVALID_ARGS", "Missing adUnitId", null)
            return null
        }
        return adUnitId
    }

    private fun loadAd(call: MethodCall, result: MethodChannel.Result) {
        val adUnitId = extractAdUnitId(call, result) ?: return
        val ctx = this.context

        if (ctx == null) {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        val instanceId = call.argument<String>("instanceId") ?: adUnitId
        release(instanceId)
        val request = Request(instanceId, adUnitId, call.argument<Number>("requestId")?.toInt() ?: 0)
        requests[instanceId] = request
        val loader = DaroLightPopupAdLoader(ctx, DaroLightPopupAdUnit(key = adUnitId, options = buildOptions(call)))
        request.loader = loader
        loader.setListener(object : DaroLightPopupAdLoaderListener {
            override fun onAdLoadSuccess(ad: DaroLightPopupAd, adInfo: DaroAdInfo) {
                if (!isCurrent(request) || request.loader !== loader) {
                    ad.destroy()
                    return
                }
                request.ad = ad
                setupAdListener(request, ad)
                sendAdInfoEvent("onAdLoadSuccess", request, adInfo)
            }

            override fun onAdLoadFail(err: DaroAdLoadError) {
                if (!isCurrent(request) || request.loader !== loader) return
                sendAdLoadErrorEvent("onAdLoadFail", request, err)
                finish(request)
            }
        })
        loader.load()
        result.success(null)
    }

    private fun buildOptions(call: MethodCall): DaroLightPopupAdOptions {
        val defaults = DaroLightPopupAdOptions()

        return DaroLightPopupAdOptions(
            backgroundColor = parseColorFromMap(call.argument<Map<*, *>>("backgroundColor")) ?: defaults.backgroundColor,
            containerColor = parseColorFromMap(call.argument<Map<*, *>>("containerColor")) ?: defaults.containerColor,
            adMarkLabelTextColor = parseColorFromMap(call.argument<Map<*, *>>("adMarkLabelTextColor")) ?: defaults.adMarkLabelTextColor,
            adMarkLabelBackgroundColor = parseColorFromMap(call.argument<Map<*, *>>("adMarkLabelBackgroundColor")) ?: defaults.adMarkLabelBackgroundColor,
            titleColor = parseColorFromMap(call.argument<Map<*, *>>("titleColor")) ?: defaults.titleColor,
            bodyColor = parseColorFromMap(call.argument<Map<*, *>>("bodyColor")) ?: defaults.bodyColor,
            ctaBackgroundColor = parseColorFromMap(call.argument<Map<*, *>>("ctaBackgroundColor")) ?: defaults.ctaBackgroundColor,
            ctaTextColor = parseColorFromMap(call.argument<Map<*, *>>("ctaTextColor")) ?: defaults.ctaTextColor,
            closeButtonText = call.argument<String>("closeButtonText") ?: defaults.closeButtonText,
            closeButtonColor = parseColorFromMap(call.argument<Map<*, *>>("closeButtonColor")) ?: defaults.closeButtonColor,
        )
    }

    private fun parseColorFromMap(map: Map<*, *>?): Int? {
        if (map == null) return null
        val r = (map["r"] as? Number)?.toInt() ?: return null
        val g = (map["g"] as? Number)?.toInt() ?: return null
        val b = (map["b"] as? Number)?.toInt() ?: return null
        val a = (map["a"] as? Number)?.toInt() ?: return null
        return Color.argb(a, r, g, b)
    }

    private fun setupAdListener(request: Request, ad: DaroLightPopupAd) {
        ad.setListener(object : DaroLightPopupAdListener {
            override fun onShown(adInfo: DaroAdInfo) {
                if (!isCurrent(request) || request.ad !== ad) return
                sendAdInfoEvent("onAdShown", request, adInfo)
            }

            override fun onFailedToShow(adInfo: DaroAdInfo, error: DaroAdDisplayFailError) {
                if (!isCurrent(request) || request.ad !== ad) return
                finish(request)
                sendAdDisplayErrorEvent("onAdFailedToShow", request, error)
            }

            override fun onDismiss(adInfo: DaroAdInfo) {
                if (!isCurrent(request) || request.ad !== ad) return
                finish(request)
                sendAdInfoEvent("onAdDismiss", request, adInfo)
            }

            override fun onAdClicked(adInfo: DaroAdInfo) {
                if (!isCurrent(request) || request.ad !== ad) return
                sendAdInfoEvent("onAdClicked", request, adInfo)
            }

            override fun onAdImpression(adInfo: DaroAdInfo) {
                if (!isCurrent(request) || request.ad !== ad) return
                sendAdInfoEvent("onAdImpression", request, adInfo)
            }
        })
    }

    private fun isAdReady(call: MethodCall, result: MethodChannel.Result) {
        val adUnitId = extractAdUnitId(call, result) ?: return
        val request = matchingRequest(call, adUnitId)
        val ready = request?.ad != null && !request.showing
        result.success(ready)
    }

    private fun showAd(call: MethodCall, result: MethodChannel.Result) {
        val adUnitId = extractAdUnitId(call, result) ?: return

        val request = matchingRequest(call, adUnitId)
        val ad = request?.ad
        if (ad == null || request.showing) {
            result.error("AD_NOT_LOADED", "Ad not loaded", null)
            return
        }

        val activity = this.activity
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        request.showing = true
        try {
            ad.show(activity)
            result.success(null)
        } catch (error: Exception) {
            finish(request)
            result.error("SHOW_FAILED", error.message, null)
        }
    }

    private fun destroyAd(call: MethodCall, result: MethodChannel.Result) {
        val adUnitId = extractAdUnitId(call, result) ?: return

        release(call.argument<String>("instanceId") ?: adUnitId)
        result.success(null)
    }

    private fun matchingRequest(call: MethodCall, adUnitId: String): Request? {
        val request = requests[call.argument<String>("instanceId") ?: adUnitId] ?: return null
        val requestId = call.argument<Number>("requestId")?.toInt() ?: 0
        return request.takeIf { it.requestId == requestId }
    }

    private fun isCurrent(request: Request) = requests[request.instanceId] === request

    private fun finish(request: Request) {
        val loader = request.loader
        val ad = request.ad
        request.ad = null
        request.loader = null
        request.showing = false
        // Revoke ownership before cancelling native work or synchronous callbacks.
        loader?.destroy()
        ad?.destroy()
    }

    private fun release(instanceId: String) {
        val request = requests.remove(instanceId) ?: return
        finish(request)
    }

    fun destroyAll() {
        requests.keys.toList().forEach(::release)
    }

    fun detachFromEngine() {
        eventSink = null
        destroyAll()
        mainHandler.removeCallbacksAndMessages(null)
        activity = null
        context = null
    }

    private fun adInfoToMap(adInfo: DaroAdInfo, adUnitId: String): Map<String, Any?> {
        return mapOf(
            "adUnitId" to adUnitId,
            "mediation" to adInfo.mediation?.serverName,
            "adNetwork" to adInfo.adNetwork,
            "latency" to adInfo.latency
        )
    }

    private fun sendAdInfoEvent(eventType: String, request: Request, adInfo: DaroAdInfo) {
        sendEvent(request,
            mapOf(
                "eventType" to eventType,
                "adUnitId" to request.adUnitId,
                "adInfo" to adInfoToMap(adInfo, request.adUnitId)
            )
        )
    }

    private fun sendAdLoadErrorEvent(eventType: String, request: Request, error: DaroAdLoadError) {
        sendEvent(request,
            mapOf(
                "eventType" to eventType,
                "adUnitId" to request.adUnitId,
                "error" to mapOf(
                    "code" to error.code,
                    "message" to error.message,
                    "adUnitId" to request.adUnitId
                )
            )
        )
    }

    private fun sendAdDisplayErrorEvent(eventType: String, request: Request, error: DaroAdDisplayFailError) {
        sendEvent(request,
            mapOf(
                "eventType" to eventType,
                "adUnitId" to request.adUnitId,
                "error" to mapOf(
                    "code" to -1,
                    "message" to error.message
                )
            )
        )
    }

    private fun sendEvent(request: Request, event: Map<String, Any>) {
        mainHandler.post {
            if (isCurrent(request)) {
                eventSink?.success(event + mapOf("instanceId" to request.instanceId, "requestId" to request.requestId))
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }
}
