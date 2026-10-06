class DaroAdInfo {
  final String adUnitId;
  final String? format;
  final String? mediation;
  final String? adNetwork;
  final int? latency;

  DaroAdInfo({
    required this.adUnitId,
    this.format,
    this.mediation,
    this.adNetwork,
    this.latency,
  });

  factory DaroAdInfo.fromMap(Map<dynamic, dynamic> map) {
    return DaroAdInfo(
      adUnitId: map['adUnitId'] as String,
      format: map['format'] as String?,
      mediation: map['mediation'] as String?,
      adNetwork: map['adNetwork'] as String?,
      latency: (map['latency'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adUnitId': adUnitId,
      if (format != null) 'format': format,
      if (mediation != null) 'mediation': mediation,
      if (adNetwork != null) 'adNetwork': adNetwork,
      if (latency != null) 'latency': latency,
    };
  }
}
