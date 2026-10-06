import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import '../models/daro_ad_info.dart';
import '../models/daro_ad_load_error.dart';
import '../models/daro_ad_display_error.dart';
import '../internal/ad_event_data.dart';

class DaroLightPopupStyle {
  final Color? backgroundColor;
  final Color? containerColor;
  final Color? adMarkLabelTextColor;
  final Color? adMarkLabelBackgroundColor;
  final Color? titleColor;
  final Color? bodyColor;
  final Color? ctaBackgroundColor;
  final Color? ctaTextColor;
  final String? closeButtonText;
  final Color? closeButtonColor;

  const DaroLightPopupStyle({
    this.backgroundColor,
    this.containerColor,
    this.adMarkLabelTextColor,
    this.adMarkLabelBackgroundColor,
    this.titleColor,
    this.bodyColor,
    this.ctaBackgroundColor,
    this.ctaTextColor,
    this.closeButtonText,
    this.closeButtonColor,
  });

  static Map<String, int> _colorToMap(Color color) {
    return {
      'r': color.red,
      'g': color.green,
      'b': color.blue,
      'a': color.alpha,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (backgroundColor != null) 'backgroundColor': _colorToMap(backgroundColor!),
      if (containerColor != null) 'containerColor': _colorToMap(containerColor!),
      if (adMarkLabelTextColor != null) 'adMarkLabelTextColor': _colorToMap(adMarkLabelTextColor!),
      if (adMarkLabelBackgroundColor != null) 'adMarkLabelBackgroundColor': _colorToMap(adMarkLabelBackgroundColor!),
      if (titleColor != null) 'titleColor': _colorToMap(titleColor!),
      if (bodyColor != null) 'bodyColor': _colorToMap(bodyColor!),
      if (ctaBackgroundColor != null) 'ctaBackgroundColor': _colorToMap(ctaBackgroundColor!),
      if (ctaTextColor != null) 'ctaTextColor': _colorToMap(ctaTextColor!),
      if (closeButtonText != null) 'closeButtonText': closeButtonText,
      if (closeButtonColor != null) 'closeButtonColor': _colorToMap(closeButtonColor!),
    };
  }
}

class DaroLightPopupAd {
  static const MethodChannel _methodChannel =
      MethodChannel('daro_flutter/lightpopup');
  static const EventChannel _eventChannel =
      EventChannel('daro_flutter/lightpopup_events');

  static final Map<String, DaroLightPopupAd> _instances = {};
  static StreamSubscription<dynamic>? _eventSubscription;
  static int _nextInstanceId = 0;

  final String _instanceId = (++_nextInstanceId).toString();
  int _requestId = 0;
  bool _disposed = false;

  final String adUnitId;
  final DaroLightPopupStyle style;

  void Function(DaroAdInfo adInfo)? onAdLoadSuccess;
  void Function(DaroAdLoadError error)? onAdLoadFail;
  void Function(DaroAdInfo adInfo)? onAdImpression;
  void Function(DaroAdInfo adInfo)? onAdClicked;
  void Function(DaroAdInfo adInfo)? onAdShown;
  void Function(DaroAdDisplayError error)? onAdFailedToShow;
  void Function(DaroAdInfo adInfo)? onAdDismiss;

  bool _isLoading = false;

  DaroLightPopupAd({
    required this.adUnitId,
    this.style = const DaroLightPopupStyle(),
    this.onAdLoadSuccess,
    this.onAdLoadFail,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdShown,
    this.onAdFailedToShow,
    this.onAdDismiss,
  }) {
    _instances[_instanceId] = this;
    _ensureEventChannelSetup();
  }

  static void _ensureEventChannelSetup() {
    if (_eventSubscription != null) return;

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final eventData = AdEventData.parse(event);
        if (eventData == null) return;

        final instance = _instances[eventData.event['instanceId']];
        if (instance == null ||
            instance._disposed ||
            eventData.event['requestId'] != instance._requestId) {
          return;
        }

        switch (eventData.eventType) {
          case 'onAdLoadSuccess':
            _handleAdInfoEvent(eventData.event, instance, instance.onAdLoadSuccess, resetLoading: true);
            break;
          case 'onAdLoadFail':
            _handleErrorEvent(eventData.event, instance, DaroAdLoadError.fromMap, instance.onAdLoadFail, resetLoading: true);
            break;
          case 'onAdImpression':
            _handleAdInfoEvent(eventData.event, instance, instance.onAdImpression);
            break;
          case 'onAdClicked':
            _handleAdInfoEvent(eventData.event, instance, instance.onAdClicked);
            break;
          case 'onAdShown':
            _handleAdInfoEvent(eventData.event, instance, instance.onAdShown);
            break;
          case 'onAdFailedToShow':
            _handleErrorEvent(eventData.event, instance, DaroAdDisplayError.fromMap, instance.onAdFailedToShow);
            break;
          case 'onAdDismiss':
            _handleAdInfoEvent(eventData.event, instance, instance.onAdDismiss);
            break;
        }
      },
      onError: (dynamic error) {
        print('DaroLightPopupAd event channel error: $error');
      },
    );
  }

  static void _handleAdInfoEvent(
    Map<String, dynamic> event,
    DaroLightPopupAd instance,
    void Function(DaroAdInfo)? callback,
    {bool resetLoading = false}
  ) {
    final rawAdInfo = event['adInfo'];
    if (rawAdInfo is Map) {
      if (resetLoading) instance._isLoading = false;
      callback?.call(DaroAdInfo.fromMap(Map<String, dynamic>.from(rawAdInfo)));
    }
  }

  static void _handleErrorEvent<T>(
    Map<String, dynamic> event,
    DaroLightPopupAd instance,
    T Function(Map<String, dynamic>) fromMap,
    void Function(T)? callback,
    {bool resetLoading = false}
  ) {
    final rawError = event['error'];
    if (rawError is Map) {
      if (resetLoading) instance._isLoading = false;
      callback?.call(fromMap(Map<String, dynamic>.from(rawError)));
    }
  }

  Future<void> load() async {
    _checkNotDisposed();
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _requestId++;

    try {
      final params = {
        'adUnitId': adUnitId,
        'instanceId': _instanceId,
        'requestId': _requestId,
        ...style.toMap(),
      };
      await _methodChannel.invokeMethod('loadAd', params);
    } catch (e) {
      _isLoading = false;
      rethrow;
    }
  }

  Future<bool> isReady() async {
    if (_disposed) return false;
    final requestId = _requestId;
    try {
      final result = await _methodChannel.invokeMethod<bool>('isAdReady', {
        'adUnitId': adUnitId,
        'instanceId': _instanceId,
        'requestId': requestId,
      });
      return !_disposed && _requestId == requestId && (result ?? false);
    } catch (e) {
      return false;
    }
  }

  Future<void> show() async {
    _checkNotDisposed();
    final requestId = _requestId;
    final ready = await isReady();
    _checkNotDisposed();
    if (!ready || _requestId != requestId) {
      throw Exception('Ad not ready. Load the ad first or check isReady().');
    }

    await _methodChannel.invokeMethod('showAd', {
      'adUnitId': adUnitId,
      'instanceId': _instanceId,
      'requestId': requestId,
    });
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('DaroLightPopupAd has been disposed.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _isLoading = false;
    _instances.remove(_instanceId);
    if (_instances.isEmpty) {
      final subscription = _eventSubscription;
      _eventSubscription = null;
      // Start cancellation before awaiting native teardown. A new instance may
      // subscribe while the native method is still pending.
      unawaited(subscription?.cancel());
    }
    await _methodChannel.invokeMethod('destroyAd', {
      'adUnitId': adUnitId,
      'instanceId': _instanceId,
      'requestId': _requestId,
    });
  }

  static void disposeAll() {
    for (final instance in _instances.values.toList()) {
      unawaited(
        instance.dispose().catchError(
          (Object error) { debugPrint('DaroLightPopupAd disposal error: $error'); },
        ),
      );
    }
  }
}
