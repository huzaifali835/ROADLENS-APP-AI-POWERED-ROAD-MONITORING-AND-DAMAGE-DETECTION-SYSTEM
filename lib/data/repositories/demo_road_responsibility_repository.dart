import '../models/detection.dart';
import '../models/road_responsibility.dart';
import 'road_responsibility_repository.dart';

class DemoRoadResponsibilityRepository implements RoadResponsibilityRepository {
  const DemoRoadResponsibilityRepository({
    this.searchDelay = const Duration(milliseconds: 900),
  });

  final Duration searchDelay;

  static const _mappings = <_DemoRoadMapping>[
    _DemoRoadMapping(
      id: 'demo-korangi-kmc',
      roadKeyword: 'korangi',
      normalizedRoadName: 'Korangi Road',
      partyName: 'Karachi Metropolitan Corporation',
      acronym: 'KMC',
      supervisingAuthority: 'Karachi Metropolitan Corporation',
      sourceSummary: 'Demonstration data only. RoadLens has not verified a live road-maintenance contract or public contact.',
      matchQuality: 0.90,
    ),
    _DemoRoadMapping(
      id: 'demo-university-fwo-kmc',
      roadKeyword: 'university',
      normalizedRoadName: 'University Road',
      partyName: 'Frontier Works Organization',
      acronym: 'FWO',
      supervisingAuthority: 'Karachi Metropolitan Corporation (KMC)',
      sourceSummary: 'Demonstration data only. The FWO/KMC association is an example workflow and not a verified current contract.',
      matchQuality: 0.84,
    ),
  ];

  @override
  Future<RoadResponsibilityResult> findForDetection(Detection detection) async {
    await Future<void>.delayed(searchDelay);
    final normalizedAddress = detection.address.toLowerCase();
    for (final mapping in _mappings) {
      if (normalizedAddress.contains(mapping.roadKeyword)) {
        return RoadResponsibilityResult.found(mapping.toResult());
      }
    }
    return const RoadResponsibilityResult.notFound(
      fallbackAuthority: 'Karachi Metropolitan Corporation (KMC)',
    );
  }
}

class _DemoRoadMapping {
  const _DemoRoadMapping({
    required this.id,
    required this.roadKeyword,
    required this.normalizedRoadName,
    required this.partyName,
    required this.acronym,
    required this.supervisingAuthority,
    required this.sourceSummary,
    required this.matchQuality,
  });

  final String id;
  final String roadKeyword;
  final String normalizedRoadName;
  final String partyName;
  final String acronym;
  final String supervisingAuthority;
  final String sourceSummary;
  final double matchQuality;

  RoadResponsibility toResult() => RoadResponsibility(
    id: id,
    normalizedRoadName: normalizedRoadName,
    responsiblePartyName: partyName,
    responsiblePartyAcronym: acronym,
    supervisingAuthorityName: supervisingAuthority,
    sourceTitle: 'RoadLens demo responsibility mapping',
    sourceSummary: sourceSummary,
    retrievedAt: DateTime.now(),
    isDemo: true,
    matchQuality: matchQuality,
  );
}
