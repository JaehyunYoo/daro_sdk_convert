enum DaroGdprStatus {
  optIn('OPT_IN'),
  optOut('OPT_OUT'),
  notApplicable('NOT_APPLICABLE'),
  unknown('UNKNOWN');

  const DaroGdprStatus(this.nativeName);

  final String nativeName;
}

enum DaroCcpaStatus {
  optIn('OPT_IN'),
  optOut('OPT_OUT'),
  notApplicable('NOT_APPLICABLE');

  const DaroCcpaStatus(this.nativeName);

  final String nativeName;
}

enum DaroCoppaStatus {
  child('CHILD'),
  notChild('NOT_CHILD');

  const DaroCoppaStatus(this.nativeName);

  final String nativeName;
}
