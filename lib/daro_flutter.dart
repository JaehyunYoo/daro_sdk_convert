library daro_flutter;

import 'dart:async';
import 'package:flutter/services.dart';

import 'src/consent/daro_consent_status.dart';

export 'src/consent/daro_consent_status.dart';
export 'src/models/daro_ad_info.dart';
export 'src/models/daro_ad_load_error.dart';
export 'src/models/daro_ad_display_error.dart';
export 'src/models/daro_reward_item.dart';
export 'src/interstitial_ad/daro_interstitial_ad.dart';
export 'src/rewarded_ad/daro_rewarded_ad.dart';
export 'src/appopen_ad/daro_appopen_ad.dart';
export 'src/lightpopup_ad/daro_lightpopup_ad.dart';
export 'src/banner/daro_banner_ad.dart';
export 'src/banner/daro_banner_ad_widget.dart';
export 'src/banner/daro_banner_size.dart';
export 'src/native_ad/daro_native_ad.dart';
export 'src/native_ad/native_ad_asset_type.dart';
export 'src/native_ad/daro_native_ad_widget.dart';
export 'src/native_ad/daro_ad_choices_position.dart';
export 'src/native_ad/daro_line_native_ad.dart';
export 'src/native_ad/daro_line_native_ad_widget.dart';

class DaroFlutter {
  static const MethodChannel _channel = MethodChannel('daro_flutter');
  static Completer<void>? _initCompleter;

  // === Pre-initialization Settings (Privacy) ===

  static bool isDebugMode = false;

  static DaroGdprStatus? _gdprStatus;
  static String? gdprConsentString;

  static DaroCcpaStatus? _ccpaStatus;
  static String? ccpaConsentString;

  static DaroCoppaStatus? _coppaStatus;

  static DaroGdprStatus? get gdprStatus => _gdprStatus;
  static DaroCcpaStatus? get ccpaStatus => _ccpaStatus;
  static DaroCoppaStatus? get coppaStatus => _coppaStatus;

  @Deprecated('Use DaroFlutter.setGdpr with DaroGdprStatus instead.')
  static bool? get hasGdprConsent => switch (_gdprStatus) {
        DaroGdprStatus.optIn => true,
        DaroGdprStatus.optOut => false,
        _ => null,
      };

  @Deprecated('Use DaroFlutter.setGdpr with DaroGdprStatus instead.')
  static set hasGdprConsent(bool? value) {
    _gdprStatus = switch (value) {
      true => DaroGdprStatus.optIn,
      false => DaroGdprStatus.optOut,
      null => null,
    };
  }

  @Deprecated('Use DaroFlutter.setCcpa with DaroCcpaStatus instead.')
  static bool? get doNotSell => switch (_ccpaStatus) {
        DaroCcpaStatus.optOut => true,
        DaroCcpaStatus.optIn => false,
        _ => null,
      };

  @Deprecated('Use DaroFlutter.setCcpa with DaroCcpaStatus instead.')
  static set doNotSell(bool? value) {
    _ccpaStatus = switch (value) {
      true => DaroCcpaStatus.optOut,
      false => DaroCcpaStatus.optIn,
      null => null,
    };
  }

  @Deprecated('Use DaroFlutter.setCoppa with DaroCoppaStatus instead.')
  static bool? get isTaggedForChildDirectedTreatment => switch (_coppaStatus) {
        DaroCoppaStatus.child => true,
        DaroCoppaStatus.notChild => false,
        null => null,
      };

  @Deprecated('Use DaroFlutter.setCoppa with DaroCoppaStatus instead.')
  static set isTaggedForChildDirectedTreatment(bool? value) {
    _coppaStatus = switch (value) {
      true => DaroCoppaStatus.child,
      false => DaroCoppaStatus.notChild,
      null => null,
    };
  }

  // === Public API ===

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<void> initialize() async {
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      await _channel.invokeMethod('initialize', {
        'isDebugMode': isDebugMode,
        if (_gdprStatus != null) 'gdprStatus': _gdprStatus!.nativeName,
        if (_gdprStatus == DaroGdprStatus.optIn) 'hasGdprConsent': true,
        if (_gdprStatus == DaroGdprStatus.optOut) 'hasGdprConsent': false,
        if (gdprConsentString != null) 'gdprConsentString': gdprConsentString,
        if (_ccpaStatus != null) 'ccpaStatus': _ccpaStatus!.nativeName,
        if (_ccpaStatus == DaroCcpaStatus.optOut) 'doNotSell': true,
        if (_ccpaStatus == DaroCcpaStatus.optIn) 'doNotSell': false,
        if (ccpaConsentString != null) 'ccpaConsentString': ccpaConsentString,
        if (_coppaStatus != null) 'coppaStatus': _coppaStatus!.nativeName,
        if (_coppaStatus == DaroCoppaStatus.child)
          'isTaggedForChildDirectedTreatment': true,
        if (_coppaStatus == DaroCoppaStatus.notChild)
          'isTaggedForChildDirectedTreatment': false,
      });
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }

    return _initCompleter!.future;
  }

  static Future<void> setGdpr(
    DaroGdprStatus status, {
    String? consentString,
  }) async {
    _gdprStatus = status;
    gdprConsentString = consentString;
    try {
      await _channel.invokeMethod('setGdpr', {
        'status': status.nativeName,
        if (consentString != null) 'consentString': consentString,
      });
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> setCcpa(
    DaroCcpaStatus status, {
    String? consentString,
  }) async {
    _ccpaStatus = status;
    ccpaConsentString = consentString;
    try {
      await _channel.invokeMethod('setCcpa', {
        'status': status.nativeName,
        if (consentString != null) 'consentString': consentString,
      });
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> setCoppa(DaroCoppaStatus status) async {
    _coppaStatus = status;
    try {
      await _channel.invokeMethod('setCoppa', {
        'status': status.nativeName,
      });
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> setAppMuted(bool muted) async {
    await _channel.invokeMethod('setAppMuted', muted);
  }

  static Future<void> setUserId(String userId) async {
    await _channel.invokeMethod('setUserId', userId);
  }

  static Future<void> openDebugger({String? mediation}) async {
    try {
      await _channel.invokeMethod('openDebugger', {
        if (mediation != null) 'mediation': mediation,
      });
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> setRoutingPolicyOverride(
    Map<String, double> weights,
  ) async {
    try {
      await _channel.invokeMethod('setRoutingPolicyOverride', {
        'weights': weights,
      });
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> clearRoutingPolicyOverride() async {
    try {
      await _channel.invokeMethod('clearRoutingPolicyOverride');
    } on MissingPluginException {
      return;
    }
  }

  static void resetForTesting() {
    _initCompleter = null;
    isDebugMode = false;
    _gdprStatus = null;
    gdprConsentString = null;
    _ccpaStatus = null;
    ccpaConsentString = null;
    _coppaStatus = null;
  }
}

String sayHello() {
  return 'Hello World from Daro Flutter!';
}
