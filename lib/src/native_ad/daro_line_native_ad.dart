import '../internal/ad_instance_manager.dart';
import 'native_ad_asset_type.dart';
import '../models/daro_ad_info.dart';
import '../models/daro_ad_load_error.dart';
import 'daro_line_native_ad_widget.dart';

class DaroLineNativeAd {
  final String adUnitId;
  final DaroLineNativeAdStyle? style;
  final void Function(DaroAdInfo adInfo)? onAdLoaded;
  final void Function(Set<NativeAdAssetType> assetTypes)?
      onNativeAdAssetLoaded;
  final void Function(DaroAdLoadError error)? onAdFailedToLoad;
  final void Function(DaroAdInfo adInfo)? onAdClicked;
  final void Function(DaroAdInfo adInfo)? onAdImpression;

  late final int adId;
  final AdInstanceManager _manager = AdInstanceManager.instance;

  DaroLineNativeAd({
    required this.adUnitId,
    this.style,
    this.onAdLoaded,
    this.onNativeAdAssetLoaded,
    this.onAdFailedToLoad,
    this.onAdClicked,
    this.onAdImpression,
  }) {
    adId = _manager.generateId();
    _manager.register(adId, _handleEvent);
  }

  DaroAdInfo _createAdInfo(Map<dynamic, dynamic> args) {
    final adInfoMap = args['adInfo'] as Map?;
    return DaroAdInfo(
      adUnitId: adUnitId,
      format: 'line_native',
      mediation: adInfoMap?['mediation'] as String?,
      adNetwork: adInfoMap?['adNetwork'] as String?,
      latency: (adInfoMap?['latency'] as num?)?.toInt(),
    );
  }

  void _handleEvent(String event, Map<dynamic, dynamic> args) {
    switch (event) {
      case 'onNativeAdAssetLoaded':
        onNativeAdAssetLoaded?.call(
          NativeAdAssetType.fromPlatform(args['assetTypes'] as List? ?? []),
        );
        break;
      case 'onAdLoaded':
        onAdLoaded?.call(_createAdInfo(args));
        break;
      case 'onAdFailedToLoad':
        final errorMap = args['error'] as Map?;
        if (errorMap != null) {
          onAdFailedToLoad?.call(DaroAdLoadError(
            code: errorMap['code'] as int? ?? -1,
            message: errorMap['message'] as String? ?? 'Unknown error',
            adUnitId: adUnitId,
          ));
        }
        break;
      case 'onAdClicked':
        onAdClicked?.call(_createAdInfo(args));
        break;
      case 'onAdImpression':
        onAdImpression?.call(_createAdInfo(args));
        break;
    }
  }

  Future<void> load() async {
    _manager.markReadyForView(adId);
    final Map<String, dynamic> arguments = {
      'adId': adId,
      'adUnitId': adUnitId,
    };

    if (style != null) {
      arguments.addAll(style!.toMap());
    }

    await _manager.invoke('loadLineNativeAd', arguments);
  }

  Future<void> dispose() async {
    _manager.unregister(adId);
    await _manager.invoke('disposeAd', {
      'adId': adId,
    });
  }
}
