enum NativeAdAssetType {
  title, // 광고 제목
  body, // 광고 본문
  icon, // 광고 아이콘
  media, // 광고 이미지 또는 동영상
  callToAction, // 행동 유도 버튼 문구
  advertiser; // 광고주명

  static Set<NativeAdAssetType> fromPlatform(List<dynamic> values) {
    return Set.unmodifiable(NativeAdAssetType.values.where(
      (type) => values.contains(type.name),
    ));
  }
}
