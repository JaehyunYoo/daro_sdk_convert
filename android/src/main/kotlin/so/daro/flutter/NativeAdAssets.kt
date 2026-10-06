package so.daro.flutter

import droom.daro.core.model.NativeAdAssetType

internal fun NativeAdAssetType.channelValue(): String = when (name) {
    "TITLE" -> "title"
    "BODY" -> "body"
    "ICON" -> "icon"
    "MEDIA" -> "media"
    "CALL_TO_ACTION" -> "callToAction"
    "ADVERTISER" -> "advertiser"
    else -> name.lowercase()
}
