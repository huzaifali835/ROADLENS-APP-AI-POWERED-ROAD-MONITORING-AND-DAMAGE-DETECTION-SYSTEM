class RoadResponsibility {
  const RoadResponsibility({
    required this.id,
    required this.normalizedRoadName,
    required this.responsiblePartyName,
    required this.responsiblePartyAcronym,
    required this.supervisingAuthorityName,
    required this.sourceTitle,
    required this.sourceSummary,
    required this.retrievedAt,
    required this.isDemo,
    required this.matchQuality,
    this.publicEmail,
    this.publicPhone,
    this.sourceUrl,
  });

  final String id;
  final String normalizedRoadName;
  final String responsiblePartyName;
  final String responsiblePartyAcronym;
  final String supervisingAuthorityName;
  final String? publicEmail;
  final String? publicPhone;
  final String sourceTitle;
  final String? sourceUrl;
  final String sourceSummary;
  final DateTime retrievedAt;
  final bool isDemo;
  final double matchQuality;
}

class RoadResponsibilityResult {
  const RoadResponsibilityResult.found(this.responsibility)
    : fallbackAuthority = null;

  const RoadResponsibilityResult.notFound({this.fallbackAuthority})
    : responsibility = null;

  final RoadResponsibility? responsibility;
  final String? fallbackAuthority;

  bool get found => responsibility != null;
}
