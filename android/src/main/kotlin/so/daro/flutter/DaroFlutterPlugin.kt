package so.daro.flutter

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Color
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import droom.daro.DaroCoreSDK
import droom.daro.SDKConfig
import droom.daro.sdk.Daro
import droom.daro.core.consent.CcpaStatus
import droom.daro.core.consent.CoppaStatus
import droom.daro.core.consent.GdprStatus
import droom.daro.core.model.DaroMediationType
import droom.daro.core.model.DaroNativeAdChoicePlacement
import droom.daro.core.routing.RoutingPolicy
import droom.daro.core.routing.RoutingPolicySource
import so.daro.flutter.native.DaroNativeAdFactory
import so.daro.flutter.native.DaroNativeAdViewFactory
import so.daro.flutter.native.DaroNativeAdPlatformView
import so.daro.flutter.banner.DaroBannerAdViewFactory
import so.daro.flutter.banner.DaroBannerAdPlatformView
import so.daro.flutter.linenative.DaroLineNativeAdViewFactory
import so.daro.flutter.linenative.DaroLineNativeAdPlatformView

class DaroFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private var adManagerChannel: MethodChannel? = null
  private var interstitialAdManager: DaroInterstitialAdManager? = null
  private var rewardedAdManager: DaroRewardedAdManager? = null
  private var appOpenAdManager: DaroFlutterAppOpenAdManager? = null
  private var lightPopupAdManager: DaroFlutterLightPopupAdManager? = null
  private var lightPopupMethodChannel: MethodChannel? = null
  private var lightPopupEventChannel: EventChannel? = null
  private var nativeAdViewFactory: DaroNativeAdViewFactory? = null
  private var savedRoutingPolicySource: RoutingPolicySource? = null

  companion object {
    @JvmStatic
    fun registerNativeAdFactory(
      engine: FlutterEngine,
      factoryId: String,
      factory: DaroNativeAdFactory,
    ): Boolean {
      val plugin = engine.plugins.get(DaroFlutterPlugin::class.java) as? DaroFlutterPlugin
        ?: throw IllegalStateException(
          "Could not find a DaroFlutterPlugin instance. The plugin may have not been registered."
        )
      val viewFactory = plugin.nativeAdViewFactory
        ?: throw IllegalStateException(
          "DaroFlutterPlugin is not attached to a FlutterEngine yet."
        )
      viewFactory.registerFactory(factory, factoryId)
      return true
    }

    @JvmStatic
    fun unregisterNativeAdFactory(engine: FlutterEngine, factoryId: String): DaroNativeAdFactory? {
      val plugin = engine.plugins.get(DaroFlutterPlugin::class.java) as? DaroFlutterPlugin
        ?: return null
      return plugin.nativeAdViewFactory?.unregisterFactory(factoryId)
    }
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "daro_flutter")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext

    val interstitialMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/interstitial")
    val interstitialEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/interstitial_events")

    val manager = DaroInterstitialAdManager()
    interstitialAdManager = manager

    interstitialMethodChannel.setMethodCallHandler(manager)
    interstitialEventChannel.setStreamHandler(manager)

    val rewardedMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/rewarded")
    val rewardedEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/rewarded_events")

    val rewardedManager = DaroRewardedAdManager()
    rewardedAdManager = rewardedManager

    rewardedMethodChannel.setMethodCallHandler(rewardedManager)
    rewardedEventChannel.setStreamHandler(rewardedManager)

    val appOpenMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/appopen")
    val appOpenEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/appopen_events")

    val appOpenManager = DaroFlutterAppOpenAdManager()
    appOpenManager.setApplication(context.applicationContext as? Application)
    appOpenAdManager = appOpenManager

    appOpenMethodChannel.setMethodCallHandler(appOpenManager)
    appOpenEventChannel.setStreamHandler(appOpenManager)

    val lightPopupMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/lightpopup")
    val lightPopupEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/lightpopup_events")

    val lightPopupManager = DaroFlutterLightPopupAdManager()
    lightPopupManager.setContext(context)
    lightPopupAdManager = lightPopupManager

    this.lightPopupMethodChannel = lightPopupMethodChannel
    this.lightPopupEventChannel = lightPopupEventChannel
    lightPopupMethodChannel.setMethodCallHandler(lightPopupManager)
    lightPopupEventChannel.setStreamHandler(lightPopupManager)

    // ad_manager channel: load/destroy for view-based ads
    val adMgrChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "daro_flutter/ad_manager")
    adManagerChannel = adMgrChannel
    adMgrChannel.setMethodCallHandler { call, result ->
      handleAdManager(call, result, adMgrChannel)
    }

    val nativeFactory = DaroNativeAdViewFactory(context, flutterPluginBinding.binaryMessenger)
    flutterPluginBinding.platformViewRegistry.registerViewFactory(
      "daro_native_ad_view",
      nativeFactory
    )
    nativeAdViewFactory = nativeFactory

    val bannerFactory = DaroBannerAdViewFactory(context, flutterPluginBinding.binaryMessenger)
    flutterPluginBinding.platformViewRegistry.registerViewFactory(
      "daro_banner_ad_view",
      bannerFactory
    )

    val lineNativeFactory = DaroLineNativeAdViewFactory(context, flutterPluginBinding.binaryMessenger)
    flutterPluginBinding.platformViewRegistry.registerViewFactory(
      "daro_line_native_ad_view",
      lineNativeFactory
    )
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${Build.VERSION.RELEASE}")
      }
      "initialize" -> {
        initializeDaroSDK(call, result)
      }
      "setGdpr" -> {
        setGdpr(call, result)
      }
      "setCcpa" -> {
        setCcpa(call, result)
      }
      "setCoppa" -> {
        setCoppa(call, result)
      }
      "setAppMuted" -> {
        val muted = call.arguments as? Boolean ?: false
        Daro.setAppMuted(muted)
        result.success(null)
      }
      "setUserId" -> {
        val userId = call.arguments as? String ?: ""
        Daro.setUserId(context, userId)
        result.success(null)
      }
      "openDebugger" -> {
        openDebugger(call, result)
      }
      "setRoutingPolicyOverride" -> {
        setRoutingPolicyOverride(call, result)
      }
      "clearRoutingPolicyOverride" -> {
        clearRoutingPolicyOverride(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun handleAdManager(call: MethodCall, result: Result, channel: MethodChannel) {
    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()

    when (call.method) {
      "loadBannerAd" -> {
        val adId = args["adId"] as? Int
            ?: return result.error("INVALID_ARGS", "Missing adId", null)
        val adUnitId = args["adUnitId"] as? String
            ?: return result.error("INVALID_ARGS", "Missing adUnitId", null)
        val sizeString = args["size"] as? String
            ?: return result.error("INVALID_ARGS", "Missing size", null)

        val platformView = DaroBannerAdPlatformView(
          context, adId, adUnitId, sizeString, channel
        )
        DaroAdInstanceManager.store(platformView, adId)
        result.success(null)
      }

      "loadNativeAd" -> {
        val adId = args["adId"] as? Int
            ?: return result.error("INVALID_ARGS", "Missing adId", null)
        val adUnitId = args["adUnitId"] as? String
            ?: return result.error("INVALID_ARGS", "Missing adUnitId", null)
        val factoryId = args["factoryId"] as? String
            ?: return result.error("INVALID_ARGS", "Missing factoryId", null)

        val factory = nativeAdViewFactory?.getFactory(factoryId)
            ?: return result.error("FACTORY_NOT_FOUND", "Factory not registered: $factoryId", null)

        val positionName = args["preferredAdChoicesPosition"] as? String
        val placement = positionName.toDaroNativeAdChoicePlacement()

        val platformView = DaroNativeAdPlatformView(
          context, adId, adUnitId, factory, placement, channel
        )
        DaroAdInstanceManager.store(platformView, adId)
        result.success(null)
      }

      "loadLineNativeAd" -> {
        val adId = args["adId"] as? Int
            ?: return result.error("INVALID_ARGS", "Missing adId", null)
        val adUnitId = args["adUnitId"] as? String
            ?: return result.error("INVALID_ARGS", "Missing adUnitId", null)

        val backgroundColor = parseColorFromMap(args["backgroundColor"])
        val contentColor = parseColorFromMap(args["contentColor"])
        val adMarkLabelTextColor = parseColorFromMap(args["adMarkLabelTextColor"])
        val adMarkLabelBackgroundColor = parseColorFromMap(args["adMarkLabelBackgroundColor"])

        val platformView = DaroLineNativeAdPlatformView(
          context, adId, adUnitId,
          backgroundColor, contentColor,
          adMarkLabelTextColor, adMarkLabelBackgroundColor,
          channel
        )
        DaroAdInstanceManager.store(platformView, adId)
        result.success(null)
      }

      "disposeAd" -> {
        val adId = args["adId"] as? Int
            ?: return result.error("INVALID_ARGS", "Missing adId", null)
        DaroAdInstanceManager.remove(adId)
        result.success(null)
      }

      else -> result.notImplemented()
    }
  }

  private fun openDebugger(call: MethodCall, result: Result) {
    val currentActivity = activity
      ?: return result.error("NO_ACTIVITY", "openDebugger requires a foreground Activity", null)

    val args = call.arguments as? Map<*, *>
    val mediation = args?.get("mediation") as? String
    if (mediation == null) {
      Daro.openDebugger(currentActivity)
      result.success(null)
      return
    }

    val mediationType = DaroMediationType.values().firstOrNull { it.serverName == mediation }
      ?: return result.error("INVALID_MEDIATION", "Unknown mediation: $mediation", null)

    Daro.openDebugger(currentActivity, mediationType)
    result.success(null)
  }

  private fun setRoutingPolicyOverride(call: MethodCall, result: Result) {
    if (!isHostAppDebuggable()) {
      return result.error(
        "DEBUG_ONLY",
        "setRoutingPolicyOverride is only available in debuggable builds",
        null
      )
    }

    val args = call.arguments as? Map<*, *>
    val rawWeights = args?.get("weights") as? Map<*, *>
      ?: return result.error("INVALID_ARGS", "Missing weights", null)

    val policy = parseRoutingPolicy(rawWeights)
      ?: return result.error("INVALID_WEIGHTS", "No usable weights: $rawWeights", null)

    if (savedRoutingPolicySource == null) {
      savedRoutingPolicySource = DaroCoreSDK.routingPolicySource
    }
    DaroCoreSDK.routingPolicySource = RoutingPolicySource { policy }
    result.success(null)
  }

  private fun clearRoutingPolicyOverride(result: Result) {
    if (!isHostAppDebuggable()) {
      return result.error(
        "DEBUG_ONLY",
        "clearRoutingPolicyOverride is only available in debuggable builds",
        null
      )
    }

    savedRoutingPolicySource?.let { original ->
      DaroCoreSDK.routingPolicySource = original
      savedRoutingPolicySource = null
    }
    result.success(null)
  }

  private fun isHostAppDebuggable(): Boolean =
    (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

  private fun parseColorFromMap(value: Any?): Int? {
    val map = value as? Map<*, *> ?: return null
    val r = (map["r"] as? Number)?.toInt() ?: return null
    val g = (map["g"] as? Number)?.toInt() ?: return null
    val b = (map["b"] as? Number)?.toInt() ?: return null
    val a = (map["a"] as? Number)?.toInt() ?: return null
    return Color.argb(a, r, g, b)
  }

  private fun initializeDaroSDK(call: MethodCall, result: Result) {
    try {
      val application = context.applicationContext as? Application
      if (application == null) {
        result.error(
          "INIT_ERROR",
          "Failed to get Application context",
          null
        )
        return
      }

      val args = call.arguments as? Map<*, *>
      val isDebugMode = args?.get("isDebugMode") as? Boolean ?: false

      val coppaStatus = args?.get("coppaStatus")?.let { raw ->
        parseStatus<CoppaStatus>(raw)
          ?: return result.error("INVALID_CONSENT_STATUS", "Unknown CoppaStatus: $raw", null)
      }
      val gdprStatus = args?.get("gdprStatus")?.let { raw ->
        parseStatus<GdprStatus>(raw)
          ?: return result.error("INVALID_CONSENT_STATUS", "Unknown GdprStatus: $raw", null)
      }
      val ccpaStatus = args?.get("ccpaStatus")?.let { raw ->
        parseStatus<CcpaStatus>(raw)
          ?: return result.error("INVALID_CONSENT_STATUS", "Unknown CcpaStatus: $raw", null)
      }

      val gdprString = args?.get("gdprConsentString") as? String ?: ""
      val ccpaString = args?.get("ccpaConsentString") as? String ?: ""

      coppaStatus?.let { Daro.setCoppa(context, it) }
      gdprStatus?.let { Daro.setGdpr(context, it, gdprString) }
      ccpaStatus?.let { Daro.setCcpa(context, it, ccpaString) }

      Daro.init(
        application = application,
        sdkConfig = SDKConfig.Builder()
          .setDebugMode(isDebugMode)
          .build()
      )

      result.success(null)
    } catch (e: Exception) {
      result.error(
        "INIT_ERROR",
        "Daro SDK initialization failed: ${e.message}",
        e.toString()
      )
    }
  }

  private fun setGdpr(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *>
    val raw = args?.get("status")
    val status = parseStatus<GdprStatus>(raw)
      ?: return result.error("INVALID_CONSENT_STATUS", "Unknown GdprStatus: $raw", null)
    val consentString = args?.get("consentString") as? String ?: ""
    Daro.setGdpr(context, status, consentString)
    result.success(null)
  }

  private fun setCcpa(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *>
    val raw = args?.get("status")
    val status = parseStatus<CcpaStatus>(raw)
      ?: return result.error("INVALID_CONSENT_STATUS", "Unknown CcpaStatus: $raw", null)
    val consentString = args?.get("consentString") as? String ?: ""
    Daro.setCcpa(context, status, consentString)
    result.success(null)
  }

  private fun setCoppa(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *>
    val raw = args?.get("status")
    val status = parseStatus<CoppaStatus>(raw)
      ?: return result.error("INVALID_CONSENT_STATUS", "Unknown CoppaStatus: $raw", null)
    Daro.setCoppa(context, status)
    result.success(null)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    adManagerChannel?.setMethodCallHandler(null)
    lightPopupMethodChannel?.setMethodCallHandler(null)
    lightPopupEventChannel?.setStreamHandler(null)
    lightPopupAdManager?.detachFromEngine()
    lightPopupAdManager = null
    lightPopupMethodChannel = null
    lightPopupEventChannel = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    interstitialAdManager?.setActivity(binding.activity)
    rewardedAdManager?.setActivity(binding.activity)
    appOpenAdManager?.setActivity(binding.activity)
    lightPopupAdManager?.setActivity(binding.activity)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
    interstitialAdManager?.setActivity(null)
    rewardedAdManager?.setActivity(null)
    appOpenAdManager?.setActivity(null)
    lightPopupAdManager?.setActivity(null)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    interstitialAdManager?.setActivity(binding.activity)
    rewardedAdManager?.setActivity(binding.activity)
    appOpenAdManager?.setActivity(binding.activity)
    lightPopupAdManager?.setActivity(binding.activity)
  }

  override fun onDetachedFromActivity() {
    lightPopupAdManager?.destroyAll()
    activity = null
    interstitialAdManager?.setActivity(null)
    rewardedAdManager?.setActivity(null)
    appOpenAdManager?.setActivity(null)
    lightPopupAdManager?.setActivity(null)
  }
}

internal fun parseRoutingPolicy(rawWeights: Map<*, *>): RoutingPolicy? {
  val parsed = rawWeights.entries.mapNotNull { (key, value) ->
    val name = key as? String ?: return@mapNotNull null
    val weight = (value as? Number)?.toDouble() ?: return@mapNotNull null
    val mediation = DaroMediationType.values().firstOrNull { it.serverName == name }
      ?: return@mapNotNull null
    if (!weight.isFinite() || weight <= 0.0) return@mapNotNull null
    mediation to weight
  }.toMap()

  return if (parsed.isEmpty()) null else RoutingPolicy(parsed)
}

private inline fun <reified T : Enum<T>> parseStatus(raw: Any?): T? =
    enumValues<T>().firstOrNull { it.name == raw }

private fun String?.toDaroNativeAdChoicePlacement(): DaroNativeAdChoicePlacement = when (this) {
    "topLeft"     -> DaroNativeAdChoicePlacement.TOP_LEFT
    "topRight"    -> DaroNativeAdChoicePlacement.TOP_RIGHT
    "bottomLeft"  -> DaroNativeAdChoicePlacement.BOTTOM_LEFT
    "bottomRight" -> DaroNativeAdChoicePlacement.BOTTOM_RIGHT
    else          -> DaroNativeAdChoicePlacement.BOTTOM_RIGHT
}
